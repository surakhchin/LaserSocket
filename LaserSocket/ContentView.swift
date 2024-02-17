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

    // Add the blueBoxAdded flag
    @State private var blueBoxAdded = false

    private var models: [Model] = {
        //Dynamically get our model filenames
        let filemanger = FileManager.default

        guard let path = Bundle.main.resourcePath,
              let files = try? filemanger.contentsOfDirectory(atPath: path) else {
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
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement, blueBoxAdded: $blueBoxAdded)
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            } else {
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, models: self.models)
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: Model?
    @Binding var blueBoxAdded: Bool // Add the blueBoxAdded binding

    func makeUIView(context: Context) -> ARView {
        let arView = CustomARView(frame: .zero)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if !blueBoxAdded {
            // Create a global anchor
            let globalAnchorEntity = AnchorEntity(world: [0.5, 0, -1.5]) // Adjust x, y, z as needed
            uiView.scene.addAnchor(globalAnchorEntity)

            // Create a blue box and attach it to the global anchor
            let blueBox = MeshResource.generateBox(size: 0.1)
            let blueBoxEntity = ModelEntity(mesh: blueBox, materials: [SimpleMaterial(color: .blue, isMetallic: false)])
            let blueBoxAnchorEntity = AnchorEntity(world: [0, 0, 0]) // Set the world position as needed
            blueBoxAnchorEntity.addChild(blueBoxEntity)
            globalAnchorEntity.addChild(blueBoxAnchorEntity)

            print("Debug: Initial blue box added to scene")

            blueBoxAdded = true
        }

        if let model = self.modelConfirmedForPlacement {
            if let modelEntity = model.modelEntity {
                // Create an anchor for the current model
                let currentAnchorEntity = AnchorEntity(plane: .any)
                currentAnchorEntity.addChild(modelEntity)
                uiView.scene.addAnchor(currentAnchorEntity)

                print("Debug: adding model to scene - \(model.modelName)")
            } else {
                print("Debug: unable to load modelEntity for - \(model.modelName)")
            }

            DispatchQueue.main.async {
                modelConfirmedForPlacement = nil
            }
        }
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
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
