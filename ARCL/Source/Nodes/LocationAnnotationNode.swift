//
//  LocationNode.swift
//  ARKit+CoreLocation
//
//  Created by Andrew Hart on 02/07/2017.
//  Copyright © 2017 Project Dent. All rights reserved.
//
import Foundation
import SceneKit
import CoreLocation

open class LocationAnnotationNode: LocationNode {
    /// Subnodes and adjustments should be applied to this subnode
    /// Required to allow scaling at the same time as having a 2D 'billboard' appearance
    public let annotationNode: AnnotationNode

    /// Whether the node should be scaled relative to its distance from the camera
    /// Default value (false) scales it to visually appear at the same size no matter the distance
    /// Setting to true causes annotation nodes to scale like a regular node
    /// Scaling relative to distance may be useful with local navigation-based uses
    /// For landmarks in the distance, the default is correct
    public var scaleRelativeToDistance = false

    public init(location: CLLocation?, image: UIImage) {
        let plane = SCNPlane(width: image.size.width / 100, height: image.size.height / 100)
        plane.firstMaterial!.diffuse.contents = image
        plane.firstMaterial!.lightingModel = .constant

        annotationNode = AnnotationNode(view: nil, image: image)
        annotationNode.geometry = plane

        super.init(location: location)

        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        constraints = [billboardConstraint]

        addChildNode(annotationNode)
    }

    @available(iOS 10.0, *)
    /// Use this constructor to add a UIView as an annotation.  Keep in mind that it is not live, instead it's a "snapshot" of that UIView.
    /// UIView is more configurable then a UIImage, allowing you to add background image, labels, etc.
    ///
    /// - Parameters:
    ///   - location: The location of the node in the world.
    ///   - view: The view to display at the specified location.
    public convenience init(location: CLLocation?, view: UIView) {
        self.init(location: location, image: view.image)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updatePositionAndScale(setup: Bool = false, scenePosition: SCNVector3?,
                                         locationManager: SceneLocationManager, onCompletion: (() -> Void)) {
        guard let position = scenePosition, let location = locationManager.currentLocation else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = setup ? 0.0 : 0.1

        let distance = self.location(locationManager.bestLocationEstimate).distance(from: location)

        let adjustedDistance = self.adjustedDistance(setup: setup, position: position, locationManager: locationManager)

        //The scale of a node with a billboard constraint applied is ignored
        //The annotation subnode itself, as a subnode, has the scale applied to it
        let appliedScale = self.scale
        self.scale = SCNVector3(x: 1, y: 1, z: 1)

        var scale: Float

        if scaleRelativeToDistance {
            scale = appliedScale.y
            annotationNode.scale = appliedScale
        } else {
            //Scale it to be an appropriate size so that it can be seen
            scale = Float(adjustedDistance) * 0.181
            if distance > 3_000 { scale *=  0.75 }

            annotationNode.scale = SCNVector3(x: scale, y: scale, z: scale)
        }

        self.pivot = SCNMatrix4MakeTranslation(0, -1.1 * scale, 0)

        SCNTransaction.commit()

        onCompletion()
    }
}

// MARK: - Image from View

extension UIView {

    @available(iOS 10.0, *)
    /// Gets you an image from the view.
    var image: UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }

}
