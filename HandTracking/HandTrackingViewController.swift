
import UIKit
import AVFoundation
import Vision

class HandTrackingViewController: UIViewController {
    
    var shouldScanNewHands = false
    var scannedImage: UIImage?
    
    let confidence: Float = 0.3
    
    @IBOutlet weak var previewView: PreviewView!
    
    var trackingRequests = [VNTrackObjectRequest]()
    private var requests = [VNRequest]()
    
    // VNRequest: Either Retangles or Landmarks
    var handDetectionRequest: VNRequest!
    var popupShown: Bool = false
    var timerRunning = false
    
    var timer: Timer!
    
    var imageTrackHandler = VNSequenceRequestHandler()
    
    // dictionary with current predicted names with a unique uuid as a key
    private var predictedHands = [UUID: String]()
    
    // MARK: Session Management
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    var devicePosition: AVCaptureDevice.Position = .back
    
    let session = AVCaptureSession()
    var isSessionRunning = false
    
    let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.
    
    var setupResult: SessionSetupResult = .success
    
    var videoDeviceInput:   AVCaptureDeviceInput!
    
    var videoDataOutput:    AVCaptureVideoDataOutput!
    var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func handFrame(from boundingBox: CGRect) -> CGRect {
        
        print("Box \(boundingBox)")
        //translate camera frame to frame inside the ARSKView
        let origin = CGPoint(x: boundingBox.minX * UIScreen.main.bounds.size.width, y: (1 - boundingBox.maxY) * UIScreen.main.bounds.size.height)
        let size = CGSize(width: boundingBox.width * UIScreen.main.bounds.size.width, height: boundingBox.height * UIScreen.main.bounds.size.height)
        
        let rect = CGRect(origin: origin, size: size)
        print("Rect \(rect)")
        return rect
    }
    
    func fixedOrientation(img: CIImage) -> CIImage {
        if (self.imageOrientation == .right) {
            let filter = CGAffineTransform.init(rotationAngle: CGFloat.pi / -2.0)
            let newImage = img.transformed(by: filter)
            return newImage
        } else if (self.imageOrientation == .down) {
            let filter = CGAffineTransform.init(rotationAngle: CGFloat.pi * -1.0)
            let newImage = img.transformed(by: filter)
            return newImage
        } else if (self.imageOrientation == .left) {
            let filter = CGAffineTransform.init(rotationAngle: CGFloat.pi / 2.0)
            let newImage = img.transformed(by: filter)
            return newImage
        }
        return img
    }
    
    /*
     - description: converts a CIImage to an UIImage
     */
    func convert(cmage:CIImage) -> UIImage
    {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
}

extension HandTrackingViewController {
    
    func scan() {
        shouldScanNewHands = true
    }
    
    func setupVision() {
        do {
            let visionModel = try VNCoreMLModel(for: HandsNew().model)
            handDetectionRequest = VNCoreMLRequest(model: visionModel,
                                                   completionHandler: self.handleNewHands)
        } catch {
            fatalError("error loading vision model")
        }
        
        self.requests = [handDetectionRequest]
    }
    
    func handleNewHands(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //perform all the UI updates on the main queue
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            for result in results {
                print("confidence=\(result.confidence)")
                if result.confidence >= self.confidence {
                    self.shouldScanNewHands = false
                    let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: result, completionHandler: self.handleHand)
                    trackingRequest.trackingLevel = .accurate
                    self.trackingRequests.append(trackingRequest)
                }
                
            }
        }
    }
    
    func handleHand(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            //perform all the UI updates on the main queue
            guard let observation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            
            if self.trackingRequests.count > 0 {
                for i in 0...self.trackingRequests.count - 1 {
                    
                    if self.trackingRequests[i].inputObservation.uuid == observation.uuid {
                        self.trackingRequests[i].inputObservation = observation
                    }
                }
            }
            
            guard observation.confidence >= self.confidence else {
                self.previewView.removeMask(id: observation.uuid.uuidString)
                return
            }
            
            self.previewView.removeMask(id: observation.uuid.uuidString)
            self.previewView.drawHandBoundingBox(hand: observation, id: observation.uuid.uuidString, shortname: self.predictedHands[observation.uuid])
        }
    }
    
}

extension HandTrackingViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
        let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }

        do {
            if shouldScanNewHands {
                imageTrackHandler = VNSequenceRequestHandler()
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation)
                
                let img = CIImage.init(cvPixelBuffer: pixelBuffer)
                let drawHand = self.fixedOrientation(img: img)
                scannedImage = self.convert(cmage: drawHand)
                
                try imageRequestHandler.perform(requests)
                self.previewView.removeAllMasks()
            } else {
                try imageTrackHandler.perform(trackingRequests, on: pixelBuffer, orientation: exifOrientation)
            }
        }
            
        catch {
            print(error)
        }
        
    }
    
}


extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

extension UIImage {
    
    /*
     - description: converts the image to a Base64 String format
     */
    func convertImageToBase64() -> String {
        let imageData = self.pngData()!
        return imageData.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
    }
    
    /// Returns a image that fills in newSize
    func resizedImage(newSize: CGSize) -> UIImage {
        // Guard newSize is different
        guard self.size != newSize else { return self }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
