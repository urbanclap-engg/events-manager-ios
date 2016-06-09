AnalyticsClientManager

More details here: https://urbanclap.atlassian.net/wiki/display/ENGG/Client+side+Event+Manager
How to use:

PreSetup:
1.  Figure out all the channels which can send events you want to support with 
    this new architecture. Eg, UCServer, Mixpanel, Facebook, etc.
2.  For each channel, with help of PM, create a csv for that channel that lists
    all the triggers that channel is supporting and what keys/values to expect
    for that trigger. For example, for UCServer, create a UCServerEvents.csv, 
    which could look something like this:
    
    trigger             ,   schema_type ,   event.page  ,   event.section   ,   event.action
    
    homeLoad            ,   event       ,   home        ,                   ,   load
    
    assist_clicked      ,   event       ,   devToProvide,                   ,   click
    
    How this reads is this:
    For every row in the csv, for the trigger (ideally this keyword to be defined
    by PM), it lists which keys need to be sent to that channel. Most of the values
    for these can be provided in the csv itself. For values that need to be provided
    by dev, just add the keyword devToProvide there and this will ensure the dev
    will have to take care of that value.
    Also the dot (.) separator is used in keys to introduce heirarchy.

3.  For each channel, define a class that conforms to protocol AnalyticsClientProtocol.
    Eg. Define a class UCServerEventsManager. Implement the two methods.
    Hint: Use the uc-analytics-client repo, and do composition to help implement
    atleast for UCServer.
    Example for Mixpanel, create a MixpanelEventsManager, and for the implementation
    of methods, just delegate to the Mixpanel SDK.
    
4.  In code, define a class something like AnalyticsConstant.swift

5.  Define a channel Configs structure here. Its a mapping of a channel to its config.
    Config right now has atleast two keys: csvFile, and client.
    For example:
    #define kUCServerChannel "ucServer"
    #define kMixpanelChannel "mixpanel"
    [kUCServerChannel : ["csvFile" : "UCServerEvents", "client" : UCServerEventsManager()],
    kMixpanelChannel : ["csvFile" : "MixpanelEvents", "client" : MixpanelEventsManager()]
    
6.  Define the triggerMappings structure. Maps each trigger from triggername to 
    all the channels that trigger is supporting, and for each channel, the devProvided
    values.
    Example:
    #define kHomeLoadTrigger "homeLoad" // needs to match trigger in csv
    #define kAssistClickedTrigger "assist_clicked"
    [kHomeLoadTrigger : [kUCServerChannel : [String:String](),
                        kMixpanelChannel : [String:String]()],
    kAssistClickedTrigger : [kUCServerChannel : ["event.page" : "context.pageName"]]]
    In the above example, we have set up that for home load trigger, its supposed
    to send events to uc server and mixpanel. For assist clicked, its supposed to
    send events to uc server only.
                        

Setup:
1.  In startup, before you intialize/setup any of the event tracking call
    [AnalyticsClientManager initialize...] Look at the options. Self explanatory.
    During initialize it will call setup method on each of the channel clients.
    Thats where you can initialize the respective SDKs if you want.

Triggering Events:
1.  Figure out in code whats the right place to trigger the event. And pass in 
    the correct properties to be parsed by the Manger. Example:
    AnalyticsClientManager.triggerEvent(kHomeLoadTrigger, [:])
    This will pass the following properties to the uc server channel client:
    ["schema_type": "event", 
    "event": ["page" : "home",
              "action" : "load"]]
    
    AnalyticsClientManager.triggerEvent(kAssistClickedTrigger, ["context" : ["pageName" : "listing"]])
    This will pass the following properties to the uc server channel client:
    ["schema_type": "event", 
    "event": ["page" : "listing", //provided by dev in the properties.
              "action" : "click"]]
    
    IF any of the clients want to append more properties thats upto them.