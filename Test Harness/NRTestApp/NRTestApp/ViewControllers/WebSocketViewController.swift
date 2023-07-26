//
//  WebSocketViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 7/20/23.
//

import Foundation

import UIKit

class WebSocketViewController: UIViewController, URLSessionWebSocketDelegate {
    
    // Button
    let disconnectButton : UIButton = {
        var btn = UIButton()
        btn.backgroundColor = .red
        btn.setTitle("Disconnect", for: .normal)
        return btn
    }()
    
    let sendButton : UIButton = {
        var btn = UIButton()
        btn.backgroundColor = .green
        btn.setTitle("Send", for: .normal)
        return btn
    }()
    private var webSocket : URLSessionWebSocketTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        disconnectButton.frame = CGRect(x: self.view.frame.width/2 - 100, y: self.view.frame.width/2, width: 200, height: 100)
        self.view.addSubview(disconnectButton)
        self.view.backgroundColor = .blue
        disconnectButton.addTarget(self, action: #selector(closeSession), for: .touchUpInside)
        
        sendButton.frame = CGRect(x: self.view.frame.width/2 - 100, y: disconnectButton.frame.minY-100, width: 200, height: 100)
        self.view.addSubview(sendButton)
        sendButton.addTarget(self, action: #selector(sendPlease), for: .touchUpInside)
        
        //Session
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        //Server API
        let url = URL(string:  "wss://demo.piesocket.com/v3/channel_1?api_key=oCdCMcMPQpbvNjUIzqtvF1d2X2okWpDQj4AwARJuAgtjhzKxVEjQU6IdCjwm&notify_self")
        
        //Socket
        webSocket = session.webSocketTask(with: url!)
        if #available(iOS 15.0, tvOS 15.0, *) {
                webSocket?.delegate = self
        }
        
        //Connect and handles handshake
        webSocket?.resume()
    }
    
    //MARK: Receive
    func receive(){
              let workItem = DispatchWorkItem{ [weak self] in
                  
                  self?.webSocket?.receive(completionHandler: { result in
                      
                      
                      switch result {
                      case .success(let message):
                          
                          switch message {
                          
                          case .data(let data):
                              print("Data received \(data)")
                              
                          case .string(let strMessgae):
                          print("String received \(strMessgae)")
                              
                          default:
                              break
                          }
                      
                      case .failure(let error):
                          print("Error Receiving \(error)")
                      }
                      // Creates the Recurrsion
                      self?.receive()
                  })
              }
              DispatchQueue.global().asyncAfter(deadline: .now() + 1 , execute: workItem)
    }
    
    //MARK: Send
    @objc func sendPlease(){
        let workItem = DispatchWorkItem{
            
            self.webSocket?.send(URLSessionWebSocketTask.Message.string("Hello"), completionHandler: { error in
                
                
                if error == nil {
                    // if error is nil we will continue to send messages else we will stop
                    self.sendPlease()
                }else{
                    print(error!)
                }
            })
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: workItem)
    }
    
    //MARK: Close Session
    @objc func closeSession(){
        webSocket?.cancel(with: .goingAway, reason: "You've Closed The Connection".data(using: .utf8))
    }
    
    //MARK: URLSESSION Protocols
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Connected to server")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnect from Server \(String(describing: reason))")
    }
}
