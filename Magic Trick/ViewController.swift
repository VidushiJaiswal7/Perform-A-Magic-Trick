//
//  ViewController.swift
//  Magic Trick
//
//  Created by VIdushi Jaiswal on 14/12/17.
//  Copyright © 2017 Vidushi Jaiswal. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


class ViewController: UIViewController, ARSCNViewDelegate {

    //MARK: Properties
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var magicButton: UIButton!
    @IBOutlet weak var throwButton: UIButton!
    @IBOutlet weak var helperLabel: UILabel!
    var isHatPlaced: Bool = false
    private var balls = [SCNNode]()
    
    
    //MARK: Lifecycle Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        helperLabel.layer.cornerRadius = 8
        helperLabel.layer.masksToBounds = true
        helperLabel.text = "Wait for the feature points to show and the horizontal plane to be detected.Then tap where you want the hat to be placed!"
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
      
        //Adding the tap gesture
        //Reference - StackOverflow
        let tap = UITapGestureRecognizer()
        tap.numberOfTapsRequired = 1
        tap.addTarget(self, action: #selector(viewTapped(_:)))
        sceneView.addGestureRecognizer(tap)
        
        // Configure UI
        configureUI(enableThrowButton: false, enableMagicButton: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        sceneView.session.run(configuration)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    

    //MARK: Actions
    //Placing an object using hit testing
    @IBAction func viewTapped(_ sender: UITapGestureRecognizer) {
        
        // Get tap location
        let tapLocation = sender.location(in: sceneView)
        print("View tapped")
        // Perform hit test
        let results = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        print(results)
        
        // If a hit was received, get position of
        if let result = results.first, !isHatPlaced {
            //Making sure that user cannot place more than one hat
            self.isHatPlaced = true
            placeHat(withResult: result)
            
        }
     
        configureUI(enableThrowButton: true, enableMagicButton: false)
        helperLabel.text = "Now that the hat is placed tap the throw button to throw balls into the hat!"
    }
    
    @IBAction func magicButtonPressed(_ sender: Any) {
        
      
        for ball in balls {
            if isBallInsideTheHat(node: ball) {
                if(ball.isHidden == true) {
                    helperLabel.text = "🌟\nMake the balls disappear by again pressing the magic button!"
                    ball.isHidden = false
                } else{
                    helperLabel.text = "🌟\nWant the balls again? \n Hit the magic button!"
                    ball.isHidden = true
                }
            }
        }
        
        
        self.addParticleEffects()
        configureUI(enableThrowButton: true, enableMagicButton: true)
    }
    
    
    @IBAction func throwButtonPressed(_ sender: Any) {
        
        configureUI(enableThrowButton: true, enableMagicButton: true)
        helperLabel.text = "Awesome! When you have balls in the hat tap the magic button to see the magic!"
        
 
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.02))
        sphereNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        sphereNode.physicsBody?.isAffectedByGravity = true
        sphereNode.physicsBody?.allowsResting = true
        sphereNode.physicsBody?.friction = 1.5
        sphereNode.physicsBody?.damping = 0.1
        if let lightEstimate = sceneView.session.currentFrame?.lightEstimate {
            sphereNode.light?.intensity = lightEstimate.ambientIntensity
        }
        
        
        //Placing the sphere in front
        let camera = self.sceneView.pointOfView!
        let position = SCNVector3(x: 0, y: 0, z: -0.16)
        sphereNode.position = camera.convertPosition(position, to: nil)
        sphereNode.rotation = camera.rotation
        
        //Applying force on the sphere in the direction of the camera
        let (direction, _) = self.getCameraDirection()
        let sphereDirection = direction
        sphereNode.physicsBody?.applyForce(sphereDirection, asImpulse: true)
        
        //Adding the balls to the array
        self.balls.append(sphereNode)
        print("Balls array \(balls)")
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
    }
    
    //Reference - Took help from in class Hit Testing (Placing Door) App
   func placeHat(withResult result: ARHitTestResult) {
        
        let transform = result.worldTransform
        
        let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        let hatNode = createHatForScene(inPosition: planePosition)!
        hatNode.name = "hat"
        sceneView.scene.rootNode.addChildNode(hatNode)
       
        configureUI(enableThrowButton: true, enableMagicButton: true)
        
    }
    
    private func createHatForScene(inPosition position: SCNVector3) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "art.scnassets/hat", withExtension: "scn") else {
            NSLog("Could not find hat scene")
            return nil
        }
        guard let node = SCNReferenceNode(url: url) else {
            return nil
        }
        
        node.load()
        node.position = position
        
        return node
    }
    
   
  
    // MARK: - ARSCNViewDelegate
    
    //Reference - Took help from in class Hit Testing (Placing Door) App
    private var planeNode: SCNNode?
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // Create an SCNNode for a detect ARPlaneAnchor
        guard let _ = anchor as? ARPlaneAnchor else {
            return nil
        }
        planeNode = SCNNode()
        return planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Create an SNCPlane on the ARPlane
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.3)
        plane.materials = [planeMaterial]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        
        node.addChildNode(planeNode)
    }
  
    
    //MARK: Helper functions
    //Reference - StackOverflow
    func getCameraDirection() -> (SCNVector3, SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
    

    //Reference - StackOverflow and Forums(Slack)
    func isBallInsideTheHat(node: SCNNode) -> Bool {
        let ballPosition = node.presentation.worldPosition
        guard let hat = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true) else {
            return false
        }
        let hatBody = hat.childNode(withName: "tube", recursively: true)
        var (hatBoundingBoxMin, hatBoundingBoxMax) = (hatBody?.presentation.boundingBox)!
        let size = hatBoundingBoxMax - hatBoundingBoxMin
        
        hatBoundingBoxMin = SCNVector3((hatBody?.presentation.worldPosition.x)! - size.x/2,
                                       (hatBody?.presentation.worldPosition.y)!,
                                       (hatBody?.presentation.worldPosition.z)! - size.z/2)
        hatBoundingBoxMax = SCNVector3((hatBody?.presentation.worldPosition.x)! + size.x,
                                       (hatBody?.presentation.worldPosition.y)! + size.y,
                                       (hatBody?.presentation.worldPosition.z)! + size.z)
        
        return
            ballPosition.x >= hatBoundingBoxMin.x  &&
                ballPosition.z >= hatBoundingBoxMin.z  &&
                ballPosition.x < hatBoundingBoxMax.x  &&
                ballPosition.y < hatBoundingBoxMax.y  &&
                ballPosition.z < hatBoundingBoxMax.z
    }

    
    func configureUI(enableThrowButton: Bool, enableMagicButton: Bool) {
    
        throwButton.isEnabled = enableThrowButton
        magicButton.isEnabled = enableMagicButton
    }
    
    //Adding particle effects when magic button is pressed
    private func addParticleEffects() {
        guard let hat = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true) else { return }
        let sparkles = SCNParticleSystem(named: "sparkles", inDirectory: nil)!
        hat.addParticleSystem(sparkles)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


 //MARK: SCNVector3 Functions
    
    func + (left: SCNVector3, right : SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    func - (left: SCNVector3, right : SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
}
