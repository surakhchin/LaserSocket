import SwiftUI
import RealityKit
import SocketIO
import ARKit
import FocusEntity

struct ContentView: View {
    @EnvironmentObject var socketConnection: SocketConnection
//    @State private var selectedModel: Model?
//    @State private var modelConfirmedForPlacement: Model?
//    @State private var isPlacementEnabled = false
    
    
    @State private var isPlacementEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement: Model?
    
//    var models: [Model] = {
//        // Dynamically grab file names
//        let fileManager = FileManager.default
//        
//        guard let path = Bundle.main.resourcePath,
//              let files = try? fileManager.contentsOfDirectory(atPath: path) else {
//            return []
//        }
//        
//        var availableModels: [Model] = []
//        
//        for filename in files where filename.hasSuffix("usdz") {
//            let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
//            
//            let model = Model(modelName: modelName)
//            availableModels.append(model)
//        }
//        return availableModels
//    }()
    
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
//    ["fender_stratocaster", "robot_walk_idle", "toy_biplane_idle", "tv_retro"]
//
    var body: some View {
        
        ZStack(alignment: .bottom) {
//            ARViewContainer(modelConfirmedForPlacement: $modelConfirmedForPlacement)
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
            } else {
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled, selectedModel: self.$selectedModel, models: self.models)
            }
        }
        


        
//        ZStack(alignment: .bottom) {
//            ARViewContainer(modelConfirmedForPlacement: $modelConfirmedForPlacement)
//            
//            if isPlacementEnabled {
//                PlacementButtonsView(isPlacementEnabled: $isPlacementEnabled, selectedModel: $selectedModel, modelConfirmedForPlacement: $modelConfirmedForPlacement)
//            } else {
//                ModelPickerView(selectedModel: $selectedModel, isPlacementEnabled: $isPlacementEnabled, models: models)
//            }
//        }
//        .edgesIgnoringSafeArea(.all)
//        .onAppear {
//            // Additional setup or events related to ARViewContainer
//            // You can access socketConnection here to handle socket events
//        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: Model?
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = CustomARView(frame: .zero)
            
//        let arView = ARView(frame: .zero)
        
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal, .vertical]
//        config.environmentTexturing = .automatic
//        
//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
//            config.sceneReconstruction = .mesh
//        }
//        
//        arView.session.run(config)
        
        return arView
    }
    
    
    //COMMENT THIS CODE
    func updateUIView(_ uiView: ARView, context: Context) {
        
        if let model = self.modelConfirmedForPlacement {
            
            if let modelEntity = model.modelEntity {
                print("Debug: adding model to scene - \(model.modelName)")
                
                let anchorEntity = AnchorEntity(plane: .any)
                anchorEntity.addChild(modelEntity)
                
                
//                let anchorEntity = AnchorEntity(plane: .any)
//                anchorEntity.addChild(modelEntity.clone(recursive: true))
                
                uiView.scene.addAnchor(anchorEntity)
            } else {
                print("Debug: unable to load modelEntity for - \(model.modelName)")
            }
            
            
            
            
            
//            let filename = modelName + ".usdz"
//            let modelEntity = try! ModelEntity.loadModel(named: filename)
//            
//            let anchorEntity = AnchorEntity(plane: .any)
//            anchorEntity.addChild(modelEntity)
//            
//            uiView.scene.addAnchor(anchorEntity)
            
            DispatchQueue.main.async {
                modelConfirmedForPlacement = nil
            }
        }
        
//        if let model = modelConfirmedForPlacement {
//            if let modelEntity = model.modelEntity {
//                let anchorEntity = AnchorEntity(plane: .any)
//                anchorEntity.addChild(modelEntity)
//                uiView.scene.addAnchor(anchorEntity)
//            } else {
//                print("Debug: Unable to load model entity for - \(model.modelName)")
//            }
//            
//            DispatchQueue.main.async {
//                modelConfirmedForPlacement = nil
//            }
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
    
    
//    @Binding var isPlacementEnabled: Bool
//    @Binding var selectedModel: Model?
//    @Binding var modelConfirmedForPlacement: Model?
//    
//    var body: some View {
//        HStack {
//            // Cancel Button
//            Button(action: {
//                print("Debug: Model Placement Cancelled")
//                resetPlacementParameters()
//            }) {
//                Image(systemName: "xmark")
//                    .frame(width: 60, height: 60)
//                    .font(.title)
//                    .background(Color.white.opacity(0.75))
//                    .cornerRadius(30)
//                    .padding(20)
//            }
//            
//            // Confirm Button
//            Button(action: {
//                print("Debug: Model Placement Confirmed")
//                modelConfirmedForPlacement = selectedModel
//                resetPlacementParameters()
//            }) {
//                Image(systemName: "checkmark")
//                    .frame(width: 60, height: 60)
//                    .font(.title)
//                    .background(Color.white.opacity(0.75))
//                    .cornerRadius(30)
//                    .padding(20)
//            }
//        }
//    }
//    
//    func resetPlacementParameters() {
//        isPlacementEnabled = false
//        selectedModel = nil
//    }
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
                            .aspectRatio(1, contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
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
//    @Binding var selectedModel: Model?
//    @Binding var isPlacementEnabled: Bool
//    var models: [Model]
//    
//    var body: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 30) {
//                ForEach(models, id: \.modelName) { model in
//                    Button(action: {
//                        print("Debug: Selected Model with name: \(model.modelName)")
//                        selectedModel = model
//                        isPlacementEnabled = true
//                    }) {
//                        Image(systemName: "photo")
//                            .resizable()
//                            .frame(height: 80)
//                            .aspectRatio(1/1, contentMode: .fit)
//                            .background(Color.white)
//                            .cornerRadius(12)
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//            .padding(20)
//            .background(Color.black.opacity(0.5))
//        }
//    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
