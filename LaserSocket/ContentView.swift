//
//  ContentView.swift
//  LaserSocket
//
//  Created by Sergey Urakhchin on 2/9/24.
//

import SwiftUI
import RealityKit
import SocketIO
import ARKit
import FocusEntity

struct ContentView: View {
    @EnvironmentObject var socketConnection: SocketConnection
    @State private var isPlacementEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement: Model?
    @State private var socketData: Any?
    @State private var initialAlpha: Double?
    @State private var hitData: Any?

    // Add the blueBoxAdded flag
    @State private var blueBoxAdded = false

    private var models: [Model] = {
        // Dynamically get our model filenames
        let fileManager = FileManager.default

        guard let path = Bundle.main.resourcePath,
              let files = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var availableModels: [Model] = []
        for filename in files where filename.hasSuffix("usdz") {
            let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
            let model = Model(modelName: modelName)
            availableModels.append(model)
        }
        return availableModels
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement, blueBoxAdded: self.$blueBoxAdded, socketData: self.$socketData, initialAlpha: self.$initialAlpha, hitData: self.$hitData)
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement, blueBoxAdded: self.$blueBoxAdded)
            } else {
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, models: self.models)
            }
        }
        .onAppear {
            // Observe changes in the SocketConnection shared instance
            socketConnection.socket.on("laserSocketServer") { data, ack in
                if let jsonArray = data as? [[String: Any]], let firstItem = jsonArray.first {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: firstItem, options: [])
                        let coordinatesData = try JSONDecoder().decode(CoordinatesData.self, from: jsonData)
//                        print("Decoded CoordinatesData: \(coordinatesData)")
                        self.socketData = coordinatesData
                    } catch {
                        print("Error decoding CoordinatesData: \(error)")
                    }
                } else {
                    print("Received data is not a valid array of dictionaries.")
                }
            }
            socketConnection.socket.on("chat message") { data, ack in
                if let dataArray = data as? [String], let hitString = dataArray.first {
                    // Assuming "hit" is the only expected string in the array
                    DispatchQueue.main.async {
                        print("Received chat message: \(hitString)")
                        self.hitData = ChatMessageData(message: hitString)
                    }
                } else {
                    print("Received data is not a valid array or does not contain the expected string.")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SocketConnection.shared)
    }
}

struct CoordinatesData: Codable {
    let alpha: Double
    let beta: Double
    let gamma: Double
}

struct ChatMessageData: Codable {
    let message: String
    // Add other properties as needed
}

class BlueBoxContainer {
    var blueBoxEntity: ModelEntity?

    init(blueBoxEntity: ModelEntity? = nil) {
        self.blueBoxEntity = blueBoxEntity
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: Model?
    @Binding var blueBoxAdded: Bool // Add the blueBoxAdded binding
    @Binding var socketData: Any?
    @Binding var initialAlpha: Double?
    @Binding var hitData: Any?

    func makeUIView(context: Context) -> ARView {
        let arView = CustomARView(frame: .zero)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Code for models:
        var alpha: Double = 0.0

        if let model = self.modelConfirmedForPlacement {
            if let modelEntity = model.modelEntity {
                print("Debug: adding model to scene - \(model.modelName)")

                let anchorEntity = AnchorEntity(plane: .any)
                anchorEntity.addChild(modelEntity)
                uiView.scene.addAnchor(anchorEntity)
            } else {
                print("Debug: Unable to load modelEntity for - \(model.modelName)")
            }
        }

        DispatchQueue.main.async {
            self.modelConfirmedForPlacement = nil
        }

        // Code for blue box
        guard let coordinatesData = self.socketData as? CoordinatesData else {
            print("Error converting CoordinatesData")
            return
        }

        if initialAlpha == nil {
            DispatchQueue.main.async {
                initialAlpha = coordinatesData.alpha
                print("Initial Alpha (set): \(String(format: "%.3f", initialAlpha ?? 0.0))")
            }
        }

        if let initialAlpha = initialAlpha {
            alpha = (coordinatesData.alpha - initialAlpha) * .pi / 180.0
        } else {
            print("Error: initialAlpha is nil")
            return
        }
        let beta = coordinatesData.beta * .pi / 180.0
        let gamma = -coordinatesData.gamma * .pi / 180.0 + .pi / 2

        if !blueBoxAdded {
            let blueBox = MeshResource.generateBox(size: [0.02, 0.1, 0.2])
            let newBlueBoxEntity = ModelEntity(mesh: blueBox, materials: [SimpleMaterial(color: .blue, isMetallic: false)])

            let anchorEntity = AnchorEntity()
            anchorEntity.position = simd_float3(0, -0.5, -1)
            anchorEntity.name = "BlueBoxAnchor"
            anchorEntity.addChild(newBlueBoxEntity)

            anchorEntity.orientation = simd_quatf(angle: Float(alpha), axis: [0, 1, 0]) *
                                      simd_quatf(angle: Float(beta), axis: [1, 0, 0]) *
                                      simd_quatf(angle: Float(gamma), axis: [0, 0, 1])

            uiView.scene.addAnchor(anchorEntity)

            print("Debug: Blue box added to scene")

            DispatchQueue.main.async {
                self.blueBoxAdded = true
            }
        } else {
            if let existingBlueBoxAnchor = uiView.scene.anchors.first(where: { $0.name == "BlueBoxAnchor" }) {
                existingBlueBoxAnchor.orientation = simd_quatf(angle: Float(alpha), axis: [0, 1, 0]) *
                                                    simd_quatf(angle: Float(beta), axis: [1, 0, 0]) *
                                                    simd_quatf(angle: Float(gamma), axis: [0, 0, 1])
            }
        }
        print("Converted CoordinatesData: CoordinatesData(alpha: \(String(format: "%.3f", coordinatesData.alpha)), beta: \(String(format: "%.3f", coordinatesData.beta)), gamma: \(String(format: "%.3f", coordinatesData.gamma))), \(initialAlpha != nil ? "Initial Alpha: \(String(format: "%.3f", initialAlpha!))" : "Initial Alpha: nil")")
        
//        // Print statement for hitData
//        if let hitData = self.hitData as? ChatMessageData {
//            print("Received chat message: \(hitData.message)")
//        }
    }
}

class CustomARView: ARView {
    let focusSquare = FESquare()

    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        focusSquare.viewDelegate = self
        focusSquare.delegate = self
        focusSquare.setAutoUpdate(to: true)
        setupARView()
    }

    @MainActor required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupARView() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        self.session.run(config)
    }
}

extension CustomARView: FEDelegate {
    func toTrackingState() {
        print("tracking")
    }

    func toInitializingState() {
        print("initializing")
    }
}

struct PlacementButtonsView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?
    @Binding var modelConfirmedForPlacement: Model?
    @Binding var blueBoxAdded: Bool

    var body: some View {
        HStack {
            // Cancel Button
            Button(action: {
                print("Debug: Cancel model placement.")
                self.resetPlacementParameters()
            }, label: {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white)
                    .opacity(0.75)
                    .cornerRadius(30)
                    .padding(20)
            })
            // Confirm Button
            Button(action: {
                self.resetPlacementParameters()
                self.modelConfirmedForPlacement = self.selectedModel
            }, label: {
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white)
                    .opacity(0.75)
                    .cornerRadius(30)
                    .padding(20)
            })
        }.frame(maxHeight: .infinity, alignment: .bottom)
    }

    func resetPlacementParameters(){
        self.isPlacementEnabled = false
    }
}

struct ModelPickerView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: Model?

    var models: [Model]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count) { index in
                    Button(action: {
                        print("DEBUG: selected model with name: \(self.models[index].modelName)")

                        self.selectedModel = self.models[index]
                        self.isPlacementEnabled = true
                    }) {
                        Image(uiImage: self.models[index].image)
                            .resizable()
                            .frame(height: 80)
                            .aspectRatio(1, contentMode: .fill)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

#if DEBUG
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//            .environmentObject(SocketConnection.shared)
//    }
//}
#endif
