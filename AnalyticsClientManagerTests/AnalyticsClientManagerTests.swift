//
//  AnalyticsClientManagerTests.swift
//  AnalyticsClientManagerTests
//
//  Created by Kanav Arora on 06/06/16.
//  Copyright © 2016 Kanav Arora. All rights reserved.
//

import XCTest
@testable import AnalyticsClientManager

class TestChannel: NSObject, AnalyticsClientProtocol {
    var events:[[String: AnyObject]] = []
    func setup() {
        events = []
    }
    
    func sendEvent(props: [String : AnyObject]) {
        events.append(props)
    }
    
    func getEvents() -> [[String: AnyObject]] {
        return events
    }
    
    func flushEvents() {
        events = []
    }
}

class AnalyticsClientManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        AnalyticsClientManager.tearDown()
    }
    
    func testMultiLevelSet() {
        var event = [String: AnyObject]()
        [AnalyticsClientManager.setValueInMultiLevelDict(&event, multiLevelKey: "key1", val: "val1")]
        XCTAssert(event["key1"] as! String == "val1")
        
        var copyEvent = event
        [AnalyticsClientManager.setValueInMultiLevelDict(&event, multiLevelKey: "key1.key2", val: "val2")] // shouldnt do anything, not possible.
        XCTAssert(NSDictionary(dictionary: event).isEqualToDictionary(copyEvent))
        
        copyEvent = event
        [AnalyticsClientManager.setValueInMultiLevelDict(&event, multiLevelKey: "key1.key2.key3", val: "val2")] // shouldnt do anything, not possible.
        XCTAssert(NSDictionary(dictionary: event).isEqualToDictionary(copyEvent))
    
        [AnalyticsClientManager.setValueInMultiLevelDict(&event, multiLevelKey: "key2.key3", val: "val3")]
        XCTAssert(event["key2"]!["key3"] == "val3")

        [AnalyticsClientManager.setValueInMultiLevelDict(&event, multiLevelKey: "key2.key4", val: "val4")]
        XCTAssert(event["key2"]!["key3"] == "val3")
        XCTAssert(event["key2"]!["key4"] == "val4")
        
    }
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let testChannel = TestChannel()
        let testChannelConfig = ChannelConfig(csvFile: "testChannelEvents", channelClient: testChannel)
        let channelConfigs:[Channel: ChannelConfig] = ["testChannel" : testChannelConfig]
        let triggerEvents = ["trigger1" : ["testChannel" : [String:String]()],
                             "trigger2" : ["testChannel" : ["eventKey2":"devOverridenKey2"]],
                             "trigger3" : ["testChannel" : ["keyParent.keyChild" : "devOverridenParent.devOverridenChild"]]]
        AnalyticsClientManager.initialize(channelConfigs,
                                          triggerEventMappings: triggerEvents,
                                          enableStrictKeyValidation: true,
                                          enableAlertOnError: false,
                                          bundle: NSBundle(forClass: self.dynamicType))
        
        
        AnalyticsClientManager.triggerEvent("trigger1", props: nil)
        XCTAssert(testChannel.getEvents().count == 1)
        
        AnalyticsClientManager.triggerEvent("trigger2", props: nil)
        XCTAssert(testChannel.getEvents().count == 1) // this should have failed, so no events added, console should alert
        
        //checking event
        let event = testChannel.getEvents()[0]
        let resEvent1 = ["eventKey1" : "val1", "keyParent" : ["keyChild" : "childVal"]]
        XCTAssert(NSDictionary(dictionary: resEvent1).isEqualToDictionary(event))

        AnalyticsClientManager.triggerEvent("trigger2", props: ["devOverridenKey2": "devVal2"])
        XCTAssert(testChannel.getEvents().count == 2)
        let resEvent2 = ["eventKey1" : "val2", "eventKey2" : "devVal2"]
        XCTAssert(NSDictionary(dictionary: resEvent2).isEqualToDictionary(testChannel.getEvents()[1]))
        
        testChannel.flushEvents()
        XCTAssert(testChannel.getEvents().count == 0)
        
        // testing other data types (int)
        AnalyticsClientManager.triggerEvent("trigger2", props: ["devOverridenKey2": 3])
        XCTAssert(testChannel.getEvents().count == 1)
        let resEvent3 = ["eventKey1" : "val2", "eventKey2" : 3]
        XCTAssert(NSDictionary(dictionary: resEvent3).isEqualToDictionary(testChannel.getEvents()[0]))
        
        // testing dict type
        AnalyticsClientManager.triggerEvent("trigger2", props: ["devOverridenKey2": ["key" : "val"]])
        XCTAssert(testChannel.getEvents().count == 2)
        let resEvent4 = ["eventKey1" : "val2", "eventKey2" : ["key" : "val"]]
        XCTAssert(NSDictionary(dictionary: resEvent4).isEqualToDictionary(testChannel.getEvents()[1]))
        
        
        testChannel.flushEvents()
        XCTAssert(testChannel.getEvents().count == 0)
        
        // testing multilevel
        AnalyticsClientManager.triggerEvent("trigger3", props: ["": 3])
        XCTAssert(testChannel.getEvents().count == 0) // should console error.
        
        AnalyticsClientManager.triggerEvent("trigger3", props: ["devOverridenParent": 3])
        XCTAssert(testChannel.getEvents().count == 0) // should console error
        
        AnalyticsClientManager.triggerEvent("trigger3", props: ["devOverridenParent": ["devOverridenChild": 3]])
        XCTAssert(testChannel.getEvents().count == 1)
        let resEvent5 = ["keyParent" : ["keyChild" : 3]]
        XCTAssert(NSDictionary(dictionary: resEvent5).isEqualToDictionary(testChannel.getEvents()[0]))
    }
    
    func testExample2() {
        let testChannel = TestChannel()
        let testChannelConfig = ChannelConfig(csvFile: "testChannelEvents", channelClient: testChannel)
        let channelConfigs:[Channel: ChannelConfig] = ["testChannel" : testChannelConfig]
        let triggerEvents = ["trigger2" : ["testChannel" : [String:String]()]]
        AnalyticsClientManager.initialize(channelConfigs,
                                          triggerEventMappings: triggerEvents,
                                          enableStrictKeyValidation: true,
                                          enableAlertOnError: false,
                                          bundle: NSBundle(forClass: self.dynamicType)) // look at console log for errors
        AnalyticsClientManager.triggerEvent("trigger1", props: nil)
        XCTAssert(testChannel.getEvents().count == 0)
        
        AnalyticsClientManager.triggerEvent("trigger2", props: nil)
        XCTAssert(testChannel.getEvents().count == 0)
    }
    
    
    func testStrictKeyValidation() {
        let testChannel = TestChannel()
        let testChannelConfig = ChannelConfig(csvFile: "testChannelEvents", channelClient: testChannel)
        let channelConfigs:[Channel: ChannelConfig] = ["testChannel" : testChannelConfig]
        let triggerEvents = ["trigger2" : ["testChannel" : [String:String]()]]
        AnalyticsClientManager.initialize(channelConfigs,
                                          triggerEventMappings: triggerEvents,
                                          enableStrictKeyValidation: false,
                                          enableAlertOnError: false,
                                          bundle: NSBundle(forClass: self.dynamicType)) // look at console log for errors
        AnalyticsClientManager.triggerEvent("trigger1", props: nil)
        XCTAssert(testChannel.getEvents().count == 0)
        
        AnalyticsClientManager.triggerEvent("trigger2", props: nil) // should have still generated a console error.
        XCTAssert(testChannel.getEvents().count == 1)
        //checking event
        var event = testChannel.getEvents()[0]
        XCTAssert(event["eventKey1"]! as! String == "val2")
        XCTAssert(event["eventKey2"] == nil)
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
