//
//  AnalyticsClientManager.swift
//  AnalyticsClientManager
//
//  Created by Kanav Arora on 06/06/16.
//  Copyright © 2016 Kanav Arora. All rights reserved.
//

import Foundation

public typealias Channel = String
public typealias Trigger = String
public typealias EventKey = String
public typealias PropertyKey = String
public typealias EventValue = String
public typealias CSVProperties = [EventKey: EventValue]
public typealias DevOverrides = [EventKey: PropertyKey]

let keywordDevToProvide = "devToProvide"

open class ChannelConfig: NSObject {
    var csvFile: String?
    var channelClient : AnalyticsClientProtocol?
    
    public init(csvFile: String,
                channelClient: AnalyticsClientProtocol) {
        self.csvFile = csvFile
        self.channelClient = channelClient
    }
}

open class AnalyticsClientManager: NSObject {
    static var sharedInstance: AnalyticsClientManager?
    static var s_enableStrictKeyValidation:Bool = true
    static var s_enableAlertOnError:Bool = true
    static var s_bundle: Bundle?
    
    var channelTriggerMappings:[Channel: [Trigger: CSVProperties]] = [:] // channel-> dictionary with trigger as key
    var channelClientObjects:[Channel: AnalyticsClientProtocol] = [:]
    var triggerEventMappings:[Trigger: [Channel: DevOverrides]] = [:] // trigger-> dictionary with channel as keys and overrides as values
    
    fileprivate class func logError(_ errorString: String) {
            logError(errorString, isAlert: true)
    }
    
    fileprivate class func logError(_ errorString: String, isAlert: Bool) {
        print("AnalyticsError: \(errorString)")
        if (s_enableAlertOnError && isAlert) {
            // todo: alert
            let alert = UIAlertView(title: "Analytics Error Message", message: errorString, delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }

    open class func initialize(_ channelConfigs: [Channel: ChannelConfig],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]]) {
        initialize(channelConfigs,
                   triggerEventMappings: triggerEventMappings,
                   enableStrictKeyValidation: true,
                   enableAlertOnError: true)
    }
    
    open class func initialize(_ channelConfigs: [Channel: ChannelConfig],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]],
                          enableStrictKeyValidation: Bool,
                          enableAlertOnError: Bool) {
        initialize(channelConfigs,
                   triggerEventMappings: triggerEventMappings,
                   enableStrictKeyValidation: enableStrictKeyValidation,
                   enableAlertOnError: enableAlertOnError,
                   bundle: Bundle.main)
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
    open class func initialize(_ channelConfigs: [Channel: ChannelConfig],
                          triggerEventMappings: [Trigger: [Channel: DevOverrides]],
                          enableStrictKeyValidation: Bool,
                          enableAlertOnError: Bool,
                          bundle: Bundle) {
        // TODO: make it thread safe
        if (sharedInstance == nil) {
            s_enableAlertOnError = enableAlertOnError
            s_enableStrictKeyValidation = enableStrictKeyValidation
            s_bundle = bundle
            if (s_bundle == nil) {
                s_bundle = Bundle.main
            }
            sharedInstance = AnalyticsClientManager(channelConfigs: channelConfigs,
                                                    triggerEventMappings: triggerEventMappings)
        } else {
            logError("Already called initialize before")
        }
    }
    
    open class func tearDown() {
        if (sharedInstance != nil) {
            sharedInstance = nil
        }
    }
    
    fileprivate init(channelConfigs: [Channel: ChannelConfig],
                 triggerEventMappings: [Trigger: [Channel: DevOverrides]]) {
        for (channel, channelConfig) in channelConfigs {
            let csvFile = channelConfig.csvFile
            if (csvFile == nil) {
                AnalyticsClientManager.logError("missing csv file for config for channel: \(channel)")
                continue
            }
            
            if let channelClient = channelConfig.channelClient {
                self.channelTriggerMappings[channel] = parseCSVFileIntoAnalyticEvents(AnalyticsClientManager.s_bundle, csvFile: csvFile)
                AnalyticsClientManager.validateMissingChannelsForTriggers(channel,
                                                                          channelTriggers: self.channelTriggerMappings[channel],
                                                                          triggerEventMappings: triggerEventMappings)
                channelClient.setup()
                self.channelClientObjects[channel] = channelClient
            } else {
                AnalyticsClientManager.logError("client for config for channel: \(channel) is not of AnalyticsClientProtocol")
                continue
            }
        }
        self.triggerEventMappings = triggerEventMappings
    }
    
    fileprivate class func validateMissingChannelsForTriggers(_ channel:Channel,
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
    
    open class func triggerEvent(_ trigger: String, props: [String: AnyObject]?) {
        if let sharedInstance = sharedInstance {
           sharedInstance.triggerEvent(trigger, props: props)
        } else {
            AnalyticsClientManager.logError("AnalyticsClientManager not initialized")
        }
    }
    
    fileprivate func triggerEvent(_ trigger: Trigger, props: [String: AnyObject]?) {
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
                    guard let val = getValueInMultiLevelDict(propsObj as AnyObject, multiLevelKey: propsKey) else {
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
                    if (AnalyticsClientManager.setValueInMultiLevelDict(&eventProps, multiLevelKey: eventKey, val: eventValue as AnyObject)) {
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
    fileprivate func getValueInMultiLevelDict(_ dict: AnyObject, multiLevelKey: String) -> AnyObject? {
        let levelKeys = multiLevelKey.components(separatedBy: ".")
        var currentObj:AnyObject = dict
        for levelKey in levelKeys {
            if let currentObjDict = currentObj as? [String: AnyObject], let currentObjChild = currentObjDict[levelKey] {
                currentObj = currentObjChild
            } else {
                return nil
            }
        }
        return currentObj
    }
    
    class func setValueInMultiLevelDictHelper(_ dict:inout [String: AnyObject], i: Int, levelKeys:[String], val:AnyObject) -> Bool {
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
                        dict[levelKey] = dictChildAsDict as AnyObject?
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
                    dict[levelKey] = newChild as AnyObject?
                    return true
                } else {
                    return false
                }
                
            }
        }
    }
    
    class func setValueInMultiLevelDict(_ dict: inout [String: AnyObject], multiLevelKey: String, val: AnyObject) -> Bool {
        return setValueInMultiLevelDictHelper(&dict, i: 0, levelKeys: multiLevelKey.components(separatedBy: "."), val: val)
    }
}

