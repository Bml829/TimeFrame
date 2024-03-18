//
//  LoginScreenViewController.swift
//  TimeFrame
//
//  Created by Akram Bettayeb on 3/13/24.
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var registerButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setCustomBackImage()
        errorMessageLabel.isHidden = true
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            errorMessageLabel.text = "Please enter your email and password."
            errorMessageLabel.isHidden = false
            return
        }

        // Perform login using Firebase Authentication
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            if let error = error {
                // Handle error - show error message
                self.errorMessageLabel.text = error.localizedDescription
                self.errorMessageLabel.isHidden = false
            } else {
                // Login was successful, perform segue to Main.storyboard
                self.performSegue(withIdentifier: "loginSegueToMainStoryboard", sender: self)
            }
        }
    }

    @IBAction func forgotPasswordButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "forgotPasswordSeg", sender: self)
    }
    
    // Called when 'return' key pressed
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
        
    // Called when the user clicks on the view outside of the UITextField
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        emailTextField.text = ""
        passwordTextField.text = ""
        errorMessageLabel.isHidden = true
    }
    
}

