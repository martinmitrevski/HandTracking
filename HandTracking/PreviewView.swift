
import UIKit
import Vision
import AVFoundation

class PreviewView: UIView {
    
    private var maskLayer = [CALayer]()
    
    // MARK: AV capture properties
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    // Create a new layer drawing the bounding box
    private func createLayer(in rect: CGRect, shortname: String?, id: String) -> CAShapeLayer{
        
        let mask = CAShapeLayer()
        mask.name = id
        mask.frame = rect
        mask.cornerRadius = 5
        mask.opacity = 0.75
        mask.borderColor = UIColor.white.cgColor
        mask.borderWidth = 3.0
        
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 1)
        
        if shortname != nil {
            let textLayer = CATextLayer()
            textLayer.fontSize = 20
            textLayer.name = id
            textLayer.string = shortname!
            
            let size = textLayer.preferredFrameSize()
            textLayer.frame = CGRect(x: rect.origin.x + (rect.size.width - size.width - 10.0)/2.0, y: rect.origin.y - size.height - 6, width: size.width + 10, height: size.height + 2)
            textLayer.alignmentMode = CATextLayerAlignmentMode.center
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.6).cgColor
            textLayer.cornerRadius = 5
            maskLayer.append(textLayer)
            layer.insertSublayer(textLayer, at: 1)
        }
        
        return mask
    }
    
    func drawHandBoundingBox(hand : VNDetectedObjectObservation, id: String, shortname: String?) {
        
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -frame.height)
        
        let translate = CGAffineTransform.identity.scaledBy(x: frame.width, y: frame.height)
        
        // The coordinates are normalized to the dimensions of the processed image, with the origin at the image's lower-left corner.
        let handbounds = hand.boundingBox.applying(translate).applying(transform)
        
        let zoom = handbounds.size.width / 3.0
        
        let fr = CGRect(x: handbounds.origin.x - zoom, y: handbounds.origin.y - zoom - 5, width: handbounds.size.width + 2*zoom, height: handbounds.size.height + 2*zoom)
        
        _ = createLayer(in: fr, shortname: shortname, id: id)
        
    }
    
    func removeMask(id: String) {
        for mask in maskLayer {
            if mask.name == id {
                mask.removeFromSuperlayer()
            }
        }
    }
    
    func removeAllMasks() {
        for mask in maskLayer {
            mask.removeFromSuperlayer()
        }
        maskLayer.removeAll()
    }
    
    func numberOfMasks() -> Int {
        return maskLayer.count
    }
}
