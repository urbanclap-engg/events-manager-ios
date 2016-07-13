//
//  AnalyticsClientManager.swift
//  AnalyticsClientManager
//
//  Created by Kanav Arora on 06/06/16.
//  Copyright © 2016 Kanav Arora. All rights reserved.
//

import Foundation

public typealias Channel = String
public typealias Config = [String: AnyObject]
public typealias Trigger = String
public typealias EventKey = String
public typealias PropertyKey = String
public typealias EventValue = String
public typealias CSVProperties = [EventKey: EventValue]
public typealias DevOverrides = [EventKey: PropertyKey]

let keywordDevToProvide = "devToProvide"

public class AnalyticsClientManager: NSObject {
    static var sharedInstance: AnalyticsClientManager?
    static var s_enableStrictKeyValidation:Bool = true
    static var s_enableAlertOnError:Bool = true
    static var s_bundle: NSBundle?
    
    var channelTriggerMappings:[Channel: [Trigger: CSVProperties]] = [:] // channel-> dictionary with trigger as key
    var channelClientObjects:[Channel: AnalyticsClientProtocol] = [:]
    var triggerEventMappings:[Trigger: [Channel: DevOverrides]] = [:] // trigger-> dictionary with channel as keys and overrides as values
    
    private class func logError(errorString: String) {
            logError(errorString, isAlert: true)
    }
    
    private class func logError(errorString: String, isAlert: Bool) {
        print("AnalyticsError: \(errorString)")
        if (s_enableAlertOnError && isAlert) {
            // todo: alert
            let alert = UIAlertView(title: "Analytics Error Message", message: errorString, delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }

    public class func initialize(channelConfigs: [Channel: Config],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]]) {
        initialize(channelConfigs,
                   triggerEventMappings: triggerEventMappings)
    }
    
    public class func initialize(channelConfigs: [Channel: Config],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]],
                          enableStrictKeyValidation: Bool,
                          enableAlertOnError: Bool) {
        initialize(channelConfigs,
                   triggerEventMappings: triggerEventMappings,
                   enableStrictKeyValidation: enableStrictKeyValidation,
                   enableAlertOnError: enableAlertOnError,
                   bundle: NSBundle.mainBundle())
    }
    
    /*
     channelConfigs:
     A dictionary with channel identifier as key and a config for that channel as value.
     The config itself is a dictionary. Right now has two keys, csvFile and client.
     The csvFile is the file which describes which triggers this analytics client supports and what are the different event keys/values it expects.
     The client parameter is an object that conforms to the AnalyticsClientProtocol.
     
     triggerEventMappings: 
     A dictionary with trigger identifiers as keys. The value is a dictionary with channel as key and dev overrides as value. The dev overrides itself is a dictionary with event key as key, and value as the key it should map to from the properties provided to provide the value for the event key. To enable arbitrary depth, we use the dot (.) notation for that. So meta_context.name would map to {meta_context: {name: foo}} in the event properties. Refer to examples.
     
     enableStrictKeyValidation:
     if true, we dont send the event if all the event key properties are not specified. If false, will still generate error, but still try to send it to the appropriate channel clients.
     
     enableAlertOnError:
     If true, we alert on every error. Else we just log to console.
     
     bundle:
     NSBundle to use where csv files are from. If not there then uses mainBundle.
     */
    public class func initialize(channelConfigs: [Channel: Config],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]],
                          enableStrictKeyValidation: Bool,
                          enableAlertOnError: Bool,
                          bundle: NSBundle) {
        // TODO: make it thread safe
        if (sharedInstance == nil) {
            s_enableAlertOnError = enableAlertOnError
            s_enableStrictKeyValidation = enableStrictKeyValidation
            s_bundle = bundle
            if (s_bundle == nil) {
                s_bundle = NSBundle.mainBundle()
            }
            sharedInstance = AnalyticsClientManager(channelConfigs: channelConfigs,
                                                    triggerEventMappings: triggerEventMappings)
        } else {
            logError("Already called initialize before")
        }
    }
    
    public class func tearDown() {
        if (sharedInstance != nil) {
            sharedInstance = nil
        }
    }
    
    private init(channelConfigs: [Channel: Config],
                 triggerEventMappings: [Trigger: [Channel: DevOverrides]]) {
        for (channel, config) in channelConfigs {
            let csvFile = config["csvFile"] as? String
            if (csvFile == nil) {
                AnalyticsClientManager.logError("missing csv file for config: \(config)")
                continue
            }
            
            if let channelClient = config["client"] as? AnalyticsClientProtocol {
                self.channelTriggerMappings[channel] = parseCSVFileIntoAnalyticEvents(AnalyticsClientManager.s_bundle, csvFile: csvFile)
                AnalyticsClientManager.validateMissingChannelsForTriggers(channel,
                                                                          channelTriggers: self.channelTriggerMappings[channel],
                                                                          triggerEventMappings: triggerEventMappings)
                channelClient.setup()
                self.channelClientObjects[channel] = channelClient
            } else {
                AnalyticsClientManager.logError("client for config: \(config) is not of AnalyticsClientProtocol")
                continue
            }
        }
        self.triggerEventMappings = triggerEventMappings
    }
    
    private class func validateMissingChannelsForTriggers(channel:Channel,
                                                          channelTriggers:[Trigger : CSVProperties]?,
                                                          triggerEventMappings:[Trigger: [Channel: DevOverrides]]) {
        guard let channelTriggers = channelTriggers else {
            return
        }
        for trigger in channelTriggers.keys {
            if (triggerEventMappings[trigger] == nil || triggerEventMappings[trigger]![channel] == nil) {
                AnalyticsClientManager.logError("event missing for trigger: \(trigger) for channel: \(channel)", isAlert: false) // dont want to spam alerts during init.
            }
        }
    }
    
    public class func triggerEvent(trigger: String, props: [String: AnyObject]?) {
        if let sharedInstance = sharedInstance {
           sharedInstance.triggerEvent(trigger, props: props)
        } else {
            AnalyticsClientManager.logError("AnalyticsClientManager not initialized")
        }
    }
    
    private func triggerEvent(trigger: Trigger, props: [String: AnyObject]?) {
        // go through all the channels associated with the trigger, construct props, and send events.
        guard let triggerSpecificMappings = self.triggerEventMappings[trigger] else {
            AnalyticsClientManager.logError("trigger: \(trigger) not present in trigger mappings provided")
            return
        }
        for (channel, devOverrides) in triggerSpecificMappings {
            guard let channelClient = self.channelClientObjects[channel] else {
                AnalyticsClientManager.logError("channel \(channel) client object not present as specified for trigger: \(trigger)")
                continue;
            }
            
            guard let channelSpecificTriggers = self.channelTriggerMappings[channel] else {
                AnalyticsClientManager.logError("channel \(channel) doesn't have a csv file for defining triggers")
                continue;
            }
            
            guard let csvProperties = channelSpecificTriggers[trigger] else {
                AnalyticsClientManager.logError("trigger \(trigger) not present in csv file for channel: \(channel)")
                continue;
            }
            
            var eventProps:[String: AnyObject] = [String:AnyObject]()
            var isMissingKey = false
            for (eventKey, eventValue) in csvProperties {
                if (eventValue == keywordDevToProvide) {
                    // dev provided
                    guard let propsKey = devOverrides[eventKey] else {
                        isMissingKey = true
                        AnalyticsClientManager.logError("eventKey: \(eventKey) needs to be overriden for channel: \(channel) and trigger: \(trigger)")
                        break
                    }
                    guard let propsObj = props else {
                        isMissingKey = true
                        AnalyticsClientManager.logError("event trigger properties for channel: \(channel) trigger:\(trigger) is not provided")
                        break
                    }
                    guard let val = getValueInMultiLevelDict(propsObj, multiLevelKey: propsKey) else {
                        isMissingKey = true
                        AnalyticsClientManager.logError("path for key: \(propsKey) not present in props: \(props) for channel: \(channel) trigger:\(trigger)")
                        break
                    }
                    if (AnalyticsClientManager.setValueInMultiLevelDict(&eventProps, multiLevelKey: eventKey, val: val)) {
                        // all good
                    } else {
                        isMissingKey = true
                        AnalyticsClientManager.logError("unable to set value for key: \(eventKey) in eventProps: \(eventProps)")
                        break
                    }
                } else {
                    // non dev provided.
                    if (AnalyticsClientManager.setValueInMultiLevelDict(&eventProps, multiLevelKey: eventKey, val: eventValue)) {
                        // all good
                    } else {
                        isMissingKey = true
                        AnalyticsClientManager.logError("unable to set csv value for key: \(eventKey) in eventProps: \(eventProps) for channel: \(channel) trigger:\(trigger)")
                        break
                    }
                }
            }
            if (!isMissingKey || !AnalyticsClientManager.s_enableStrictKeyValidation) {
                channelClient.sendEvent(eventProps)
            }
        }
    }
    
    // multiLevelKey is . separted
    private func getValueInMultiLevelDict(dict: AnyObject, multiLevelKey: String) -> AnyObject? {
        let levelKeys = multiLevelKey.componentsSeparatedByString(".")
        var currentObj:AnyObject = dict
        for levelKey in levelKeys {
            if let currentObjDict = currentObj as? [String: AnyObject], currentObjChild = currentObjDict[levelKey] {
                currentObj = currentObjChild
            } else {
                return nil
            }
        }
        return currentObj
    }
    
    class func setValueInMultiLevelDictHelper(inout dict:[String: AnyObject], i: Int, levelKeys:[String], val:AnyObject) -> Bool {
        let levelKey = levelKeys[i]
        if (levelKey.isEmpty) {
            return false
        } else if (i == (levelKeys.count - 1)) {
            dict[levelKey] = val
            return true
        } else {
            if let dictChild = dict[levelKey] {
                // if already key is present
                if var dictChildAsDict = dictChild as? [String: AnyObject] {
                    // if its already a dict
                    if setValueInMultiLevelDictHelper(&dictChildAsDict, i: i+1, levelKeys: levelKeys, val: val) {
                        dict[levelKey] = dictChildAsDict
                        return true
                    } else {
                        return false
                    }
                    
                } else {
                    // if its not a dict, error
                    return false
                }
            } else {
                // create a new child at this level
                var newChild = [String: AnyObject]()
                if setValueInMultiLevelDictHelper(&newChild, i: i+1, levelKeys: levelKeys, val: val) {
                    dict[levelKey] = newChild
                    return true
                } else {
                    return false
                }
                
            }
        }
    }
    
    class func setValueInMultiLevelDict(inout dict: [String: AnyObject], multiLevelKey: String, val: AnyObject) -> Bool {
        return setValueInMultiLevelDictHelper(&dict, i: 0, levelKeys: multiLevelKey.componentsSeparatedByString("."), val: val)
    }
}

