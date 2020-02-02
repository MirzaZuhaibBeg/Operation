//
//  CustomOperation.swift
//  MirzaZuhaib
//
//  Created by Mirza Zuhaib Beg on 23/10/19.
//  Copyright © 2019 MirzaZuhaib. All rights reserved.
//

import UIKit

typealias CustomOperationHandler = (_ dataModel: DataModel?) -> Void

/// State
///
/// - Success: success
/// - Failure: failure
enum State: Int {
    
    case Success = 0
    case Failure
}

/// DataModel will save information for Data
struct DataModel {
    
    // state of data
    var state: State?
}

/// CustomOperation will make API call and update the data model accordingly. This class can be used to add operation in operation queue to perform any sequenatial or parallel data tasks. Eg: adding multiple object to server which can not be added in single API and it needs to be added one by one. This class will take data model as input and it will return same data model by updating its state such as Success or Failure
class CustomOperation: Operation {
    
    var dataModel: DataModel?
    
    var customOperationHandler: CustomOperationHandler?

    var timerTimeout: Timer?
    
    var timeout: Double = 5.0
    
    let semaphore = DispatchSemaphore(value: 0)

    //MARK:- Operation Methods
    required init (data: DataModel, handler: CustomOperationHandler?) {
        self.dataModel = data
        self.customOperationHandler = handler
    }
    
    override func main() {
        guard isCancelled == false else {
            
            // Error occured as operation is cancelled
            self.state = .Failure
            self.customOperationHandler?(self.dataModel)
            return
        }
        
        self.updateDataOnServer()
    }
    
    //MARK:- Private Methods
    /// Method to update Data On Server
    private func updateDataOnServer() {
        guard let dataModel = dataModel else {
            
            // Error occured as dataModel is invalid
            self.state = .Failure
            self.customOperationHandler?(self.dataModel)
            return
        }
        
        guard self.handleUnreachableAccessory(accessoryModel) else {
            return
        }

        // start timer for handling timeout
        self.startTimer()
        
        APIManager.shared().makeAPICall(dataModel) { [weak self] (_, error) in
            
            if error == nil {
                self?.handleAPISuccess()
            } else {
                self?.handleAPIError()
            }
        }
        
        semaphore.wait()
    }
    
    
    /// Method to handle API Success
    private func handleAPISuccess() {
        
        // invalidate timer
        self.invalidateTimer()
        
        // Success
        self.state = .Success
        self.customOperationHandler?(self.dataModel)

        self.signalSemaphore()
    }
    
    /// Method to handle Unreachable State
    ///
    /// - Returns: Bool
    private func handleUnreachableState() -> Bool {
        
        if Reachability.reachabilityState == false {
            self.state = .Failure
            self.customOperationHandler?(self.dataModel)
            return false
        }
        
        return true
    }
    
    /// Method to handle API Error
    private func handleAPIError() {
        
        // invalidate timer
        self.invalidateTimer()
        
        self.state = .Failure
        self.customOperationHandler?(self.dataModel)

        self.signalSemaphore()
    }
    
    /// Method to handle Timeout
    @objc private func handleTimeout() {
        
        // invalidate timer
        self.invalidateTimer()
        
        self.state = .Failure
        self.customOperationHandler?(self.dataModel)

        self.signalSemaphore()
    }
    
    //MARK:- Helper Methods
    /// Method to start Timer
    private func startTimer() {
        timerTimeout = Timer.init(timeInterval: timeout, target: self, selector: #selector(self.handleTimeout), userInfo: nil, repeats: false)
        RunLoop.main.add(timerTimeout!, forMode: .default)
    }

    /// Method to invalidate Timer
    private func invalidateTimer() {
        self.timerTimeout?.invalidate()
    }
    
    /// Method to signal Semaphore
    private func signalSemaphore() {
        semaphore.signal()
    }
}
