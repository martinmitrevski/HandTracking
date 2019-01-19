
import UIKit

extension UIViewController {
    
    func presentAlert(title: String = "",
                      message: String,
                      buttonTitle: String = "OK",
                      okActionHandler: ((UIAlertAction) -> Swift.Void)? = nil,
                      shouldAddCancel: Bool = false) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        if shouldAddCancel {
            let cancelAction = UIAlertAction(title: "Cancel",
                                             style: .cancel,
                                             handler: { action in
                                                alertController.dismiss(animated: true,
                                                                        completion: nil)
            })
            alertController.addAction(cancelAction)
        }
        let defaultAction = UIAlertAction(title: buttonTitle,
                                          style: .default,
                                          handler: okActionHandler)
        alertController.addAction(defaultAction)
        self.present(alertController, animated: true, completion: nil)
    }
}
