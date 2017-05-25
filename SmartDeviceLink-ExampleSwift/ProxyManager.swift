//
//  ProxyManager.swift
//  SmartDeviceLink-ExampleSwift
//
//  Copyright © 2017 smartdevicelink. All rights reserved.
//

import SmartDeviceLink
import UIKit

enum ProxyState {
    case stopped
    case searching
    case connected
}

weak var delegate: ProxyManagerDelegate?
fileprivate var firstHMIFull = true
fileprivate var isVehicleDataSubscribed = false
let appIcon = UIImage(named: "AppIcon60x60")

protocol ProxyManagerDelegate: class {
    func didChangeProxyState(_ newState: ProxyState)
}

class ProxyManager: NSObject {

    fileprivate var sdlManager: SDLManager!

    // Singleton
    static let sharedManager = ProxyManager()
    private override init() {
        super.init()
    }

    // MARK: - SDL Setup
     func startIAP() {
        delegate?.didChangeProxyState(ProxyState.searching)
        let lifecycleConfiguration = setLifecycleConfigurationPropertiesOnConfiguration(SDLLifecycleConfiguration.defaultConfiguration(withAppName: AppConstants.sdlAppName, appId: AppConstants.sdlAppID))
        startSDLManager(lifecycleConfiguration)
    }

     func startTCP() {
        delegate?.didChangeProxyState(ProxyState.searching)
        let defaultIP = ESUserDefaults.shared.ipAddress
        let defaultPort = UInt16(ESUserDefaults.shared.port!)
        let lifecycleConfiguration = setLifecycleConfigurationPropertiesOnConfiguration(SDLLifecycleConfiguration.debugConfiguration(withAppName: AppConstants.sdlAppName, appId: AppConstants.sdlAppID, ipAddress: defaultIP!, port: defaultPort!))
        startSDLManager(lifecycleConfiguration)
    }

    private func startSDLManager(_ lifecycleConfiguration: SDLLifecycleConfiguration) {
        // Configure the proxy handling RPC calls between the SDL Core and the app
        let configuration: SDLConfiguration = SDLConfiguration(lifecycle: lifecycleConfiguration, lockScreen: SDLLockScreenConfiguration.enabledConfiguration(withAppIcon: appIcon!, backgroundColor: nil))
        self.sdlManager = SDLManager(configuration: configuration, delegate: self)

        // Start watching for a connection with a SDL Core
        self.sdlManager?.start(readyHandler: { [unowned self] (success, error) in
            if success {
                delegate?.didChangeProxyState(ProxyState.connected)
				self.addRPCObservers()
				self.addPermissionManagerObservers()
                print("SDL start file manager storage: \(self.sdlManager!.fileManager.bytesAvailable / 1024 / 1024) mb")
            }
            if let error = error {
                print("Error starting SDL: \(error)")
            }
        })
    }

    private func setLifecycleConfigurationPropertiesOnConfiguration(_ configuration: SDLLifecycleConfiguration) -> SDLLifecycleConfiguration {
        configuration.shortAppName = AppConstants.sdlShortAppName
        configuration.appType = SDLAppHMIType.media()
        configuration.appIcon = SDLArtwork.persistentArtwork(with: appIcon!, name: AppConstants.appIconName, as: .PNG)

        return configuration
    }

    func send(request: SDLRPCRequest, responseHandler: SDLResponseHandler? = nil) {
        guard sdlManager.hmiLevel != .none() else {
            return
        }
        sdlManager.send(request, withResponseHandler: responseHandler)
    }

    func reset() {
        sdlManager?.stop()
        delegate?.didChangeProxyState(ProxyState.stopped)
    }
}

// MARK: SDLManagerDelegate
extension ProxyManager: SDLManagerDelegate {
    func managerDidDisconnect() {
        delegate?.didChangeProxyState(ProxyState.stopped)
    }

    func hmiLevel(_ oldLevel: SDLHMILevel, didChangeTo newLevel: SDLHMILevel) {
        // On our first HMI level that isn't none, do some setup
        if newLevel != .none() && firstHMIFull == true {
            firstHMIFull = false
        }
        // HMI state is changing from NONE or BACKGROUND to FULL or LIMITED
        if (oldLevel == .none() || oldLevel == .background())
            && (newLevel == .full() || newLevel == .limited()) {
            prepareRemoteSystem(overwrite: true) { [unowned self] in
                self.showMainImage()
                self.prepareButtons()
                self.addSpeakMenuCommand()
                self.addperformInteractionMenuCommand()
                self.setText()
                self.setDisplayLayout()
				self.subscribeVehicleData()
            }
        } else if (oldLevel == .full() || oldLevel == .limited())
            && (newLevel == .none() || newLevel == .background()) {
            // HMI state changing from FULL or LIMITED to NONE or BACKGROUND
        }
    }
}

// MARK: - Prepare Remote System
extension ProxyManager {
	fileprivate func addRPCObservers() {
		// Adding Notification Observers
		NotificationCenter.default.addObserver(self, selector: #selector(didReceiveVehicleData(_:)), name: .SDLDidReceiveVehicleData, object: nil)
	}

	fileprivate func addPermissionManagerObservers() {
		_ = sdlManager.permissionManager.addObserver(forRPCs: ["SubscribeVehicleData"], groupType: .allAllowed) { (_, _) in
		}
	}

    fileprivate func prepareRemoteSystem(overwrite: Bool = false, completionHandler: @escaping (Void) -> (Void)) {

        let group = DispatchGroup()
        group.enter()
        group.notify(queue: .main) {
            completionHandler()
        }

        // Send images
        if !sdlManager.fileManager.remoteFileNames.contains(AppConstants.mainArtwork) {
            let artwork = SDLArtwork(image: #imageLiteral(resourceName: "sdl_logo_green"), name: AppConstants.mainArtwork, persistent: true, as: .PNG)
            group.enter()
            sdlManager.fileManager.uploadFile(artwork, completionHandler: { (_, _, error) in
                group.leave()
                if let error = error {
                    print("Error uploading default artwork \(artwork) with error \(error)")
                }
            })
        }
        if !sdlManager.fileManager.remoteFileNames.contains(AppConstants.PointingSoftButtonArtworkName) {
            let buttonIconPoint = SDLArtwork(image: #imageLiteral(resourceName: "sdl_softbutton_icon"), name: AppConstants.PointingSoftButtonArtworkName, persistent: true, as: .PNG)
            group.enter()
            sdlManager.fileManager.uploadFile(buttonIconPoint, completionHandler: { (_, _, error) in
                group.leave()
                if let error = error {
                    print("Error uploading default artwork \(buttonIconPoint) with error \(error)")
                }
            })
        }
        let choice = SDLChoice(id: 113, menuName: AppConstants.menuNameOnlyChoice, vrCommands: [AppConstants.menuNameOnlyChoice])!
        let createRequest = SDLCreateInteractionChoiceSet(id: 113, choiceSet: [choice])!
        group.enter()
        sdlManager.send(createRequest) { (_, _, error) in
            group.leave()
			if let error = error {
				print("Send Failed with error: \(error)")
			}
        }
        group.leave()
    }
}

// MARK: - RPCs
extension ProxyManager {

    // MARK: Show Requests
    // Set Text
    fileprivate func setText() {
        let show = SDLShow(mainField1: AppConstants.sdl, mainField2: AppConstants.testApp, alignment: .centered())
        send(request: show!)
    }
    // Set Display Layout
    fileprivate func setDisplayLayout() {
        let display = SDLSetDisplayLayout(predefinedLayout: .non_MEDIA())!
        send(request: display)
    }
    // Show Main Image
    fileprivate func showMainImage() {
        let sdlImage = SDLImage(name: AppConstants.mainArtwork, of: .dynamic())
        let show = SDLShow()!
        show.graphic = sdlImage
        send(request: show)
    }
    // MARK: Buttons
    fileprivate func prepareButtons() {
        let softButton = SDLSoftButton()!
        softButton.softButtonID = 100
        softButton.handler = {[unowned self] (notification) in
            if let onButtonPress = notification as? SDLOnButtonPress {
                if onButtonPress.buttonPressMode.isEqual(to: SDLButtonPressMode.short()) {
                    let alert = SDLAlert()!
                    alert.alertText1 = AppConstants.pushButtonText
                    self.send(request: alert)
                }
            }
        }
        softButton.type = .both()
        softButton.text = AppConstants.buttonText
        softButton.image = SDLImage(name: AppConstants.PointingSoftButtonArtworkName, of: .dynamic())

		let show = SDLShow()!
        show.softButtons = [softButton]
        send(request: show)
    }
    // MARK: Menu Items
    fileprivate func addSpeakMenuCommand() {
        let menuParameters = SDLMenuParams(menuName: AppConstants.speakAppNameText, parentId: 0, position: 0)!

        let menuItem = SDLAddCommand(id: 111, vrCommands: [AppConstants.speakAppNameText]) {[unowned self] (notification) in
            guard let onCommand = notification as? SDLOnCommand else {
                return
            }
            if onCommand.triggerSource == .menu() {
                self.send(request: self.appNameSpeak())
            }
        }!
        menuItem.menuParams = menuParameters
        send(request: menuItem)
    }
    // MARK: Perform Interaction Functions
    fileprivate func addperformInteractionMenuCommand() {
        let menuParameters = SDLMenuParams(menuName: AppConstants.performInteractionText, parentId: 0, position: 1)!

        let menuItem = SDLAddCommand(id: 112, vrCommands: [AppConstants.performInteractionText]) {[unowned self] (notification) in
            guard let onCommand = notification as? SDLOnCommand else {
                return
            }
            if onCommand.triggerSource == .menu() {
                self.createPerformInteraction()
            }
        }!
        menuItem.menuParams = menuParameters
        send(request: menuItem)
    }

    fileprivate func createPerformInteraction() {
        let performInteraction = SDLPerformInteraction(initialPrompt: nil, initialText: AppConstants.menuNameOnlyChoice, interactionChoiceSetID: 113)!
        performInteraction.interactionMode = .manual_ONLY()
        performInteraction.interactionLayout = .list_ONLY()
        performInteraction.initialPrompt = SDLTTSChunk.textChunks(from: AppConstants.chooseOneTTS)
        performInteraction.initialText = AppConstants.initialTextInteraction
        performInteraction.helpPrompt = SDLTTSChunk.textChunks(from: AppConstants.doItText)
        performInteraction.timeoutPrompt = SDLTTSChunk.textChunks(from: AppConstants.tooLateText)
        performInteraction.timeout = 5000 // 5 seconds
        self.sdlManager.send(performInteraction) {[unowned self] (request, response, _) in
            guard let performInteractionResponse = response as? SDLPerformInteractionResponse else {
                return
            }
            // Wait for user's selection or for timeout
            if performInteractionResponse.resultCode == .timed_OUT() {
                self.send(request: self.youMissedItSpeak())
            } else if performInteractionResponse.resultCode == .success() {
                self.send(request: self.goodJobSpeak())
            }
        }
    }
    // MARK: Speak Functions
    fileprivate func appNameSpeak() -> SDLSpeak {
        let speak = SDLSpeak()
        speak?.ttsChunks = SDLTTSChunk.textChunks(from: AppConstants.sdlTTS)
        return speak!
    }

    fileprivate func goodJobSpeak() -> SDLSpeak {
        let speak = SDLSpeak()
        speak?.ttsChunks = SDLTTSChunk.textChunks(from: AppConstants.goodJobTTS)
        return speak!
    }

    fileprivate func youMissedItSpeak() -> SDLSpeak {
        let speak = SDLSpeak()
        speak?.ttsChunks = SDLTTSChunk.textChunks(from: AppConstants.missedItTTS)
        return speak!
    }
	// MARK: Vehicle Data
	fileprivate func subscribeVehicleData() {
		print("subscribeVehicleData")
		if isVehicleDataSubscribed {
			return
		}
		let subscribe = SDLSubscribeVehicleData()!

		// TODO: Add the vehicle data items you want to subscribe to
		// Specify which items to subscribe to
		subscribe.speed = true

		sdlManager.send(subscribe) { (_, response, _) in
			print("SubscribeVehicleData response from SDL: \(String(describing: response?.resultCode)) with info: \(String(describing: response?.info))")
			if response?.resultCode == SDLResult.success() {
				print(AppConstants.vehicleDataSuccess)
				isVehicleDataSubscribed = true
			}
		}
	}

	@objc fileprivate func didReceiveVehicleData(_ notification: SDLRPCNotificationNotification) {
		guard let onVehicleData = notification.notification as? SDLOnVehicleData else {
			return
		}
		print(AppConstants.vehicleDataNotification)
		// TODO: Put your vehicle data code here!
		print("Speed: \(onVehicleData.speed)")
	}
}
