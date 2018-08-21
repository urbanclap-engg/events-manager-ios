# Analytics Client Manager

Analytics client manager is a csv based events SDK which can be used to set up Analytics for your application. 

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

## Prerequisites
How to develop? (Detailed instructions here: https://www.raywenderlich.com/99386/create-cocoapod-swift)

1.  Clone this repo locally.
2.  To test changes locally, you can include this pod as a development local pod
```sh
pod 'AnalyticsClientManager', :path=> '~/projects/AnalyticsClientManager' 
```
3. Run/update unit tests in the project and make sure they pass.
4. Add a tag with this commit for this version number
```sh
git tag 0.3.0 git push -u origin master --tags
```
5. Commit to master here. 

## Presetup

-  Figure out all the channels which can send events you want to support with 
this new architecture. Eg, UCServer, Mixpanel, Facebook, etc.

- For each channel, create a csv for that channel that lists
all the triggers that channel is supporting and what keys/values to expect
for that trigger. For example, for UCServer, create a UCServerEvents.csv, 
which could look something like this:
[RAW CSV](http://github.com)

| trigger | schema_type | event.page | event.section | event.action |
| ------ | ------ | ------ | ------ | ------ |
| home_page_load | event| home || load |
| assist_clicked | event | devToProvide || click |

- How this reads is this:
For every row in the csv, for the trigger (ideally this keyword to be defined
by PM), it lists which keys need to be sent to that channel. Most of the values
for these can be provided in the csv itself. For values that need to be provided
by dev, just add the keyword devToProvide there and this will ensure the dev
will have to take care of that value.
Also the dot (.) separator is used in keys to introduce heirarchy.

- For each channel, define a class that conforms to protocol AnalyticsClientProtocol.
Eg. Define a class UCServerEventsManager. Implement the two methods.

```sh
    import AnalyticsClientManager
        
    class UCServerEventsManager : AnalyticsClientProtocol {
        @objc func setup() {
             //write your setup code
        }
        
         @objc func sendEvent(_ props: [String: AnyObject]) { 
            //implementation of sending events
        }
    }
```
Example for Mixpanel, create a MixpanelEventsManager, and for the implementation
of methods, just delegate to the Mixpanel SDK

- In code, define a class something like AnalyticsConstant.swift

```sh
     enum AnalyticsChannel: Channel {
        case UCSERVER
        case MIXPANEL
    }
        
    let channelConfigs: [Channel: ChannelConfig] =
    [
            AnalyticsChannel.UCSERVER.rawValue: ChannelConfig(csvFile: "ucserverevents_ios", channelClient: UCServerEventsManager()),
            AnalyticsChannel.MIXPANEL.rawValue: ChannelConfig(csvFile: "mixpanel_ios", channelClient: MixPanelEventsManager()),
    ]
```

- Define the triggerMappings structure. Maps each trigger from triggername to 
all the channels that trigger is supporting, and for each channel, the devProvided values. In the table above there are two events, lets take them as an example and step by step create triggerMappings.
```sh

/* defined Trigger */
enum AnalyticsTriggers : String {
    home_page_load,
    assist_clicked
}

/* define Individual Mapping */
let homePageLoadMapping = [
    AnalyticsChannel.UCSERVER.rawValue: [String: String](),
    AnalyticsChannel.MIXPANEL.rawValue: [String: String](),
]

let assistClickedMapping = [
    AnalyticsChannel.UCSERVER.rawValue: ["event.page" : "pageValue"]
]


/* trigger, channel, devOverrides are defined in Pod */
let triggerMappings : [Trigger: [Channel: DevOverrides]] = [
    AnalyticsTriggers.home_page_load.rawValue : homePageLoadMapping,
    AnalyticsTriggers.assist_clicked.rawValue : assistClickedMapping
]

/* Custom class for sending events */

class ExampleEventManager :  AnalyticsClientManager {
        class func triggerEvent(_ trigger: AnalyticsTriggers, props: [String: AnyObject]?) {
                triggerEvent(trigger.rawValue, props: props)
            }
}
            
```
In the above example, we have set up that for home load trigger, its supposed
to send events to uc server and mixpanel. For assist clicked, its supposed to
send events to uc server only.


#### Setup

- In startup, before you intialize/setup any of the event tracking call [AnalyticsClientManager initialize...] Look at the options. Self explanatory. During initialize it will call setup method on each of the channel clients. Thats where you can initialize the respective SDKs if you want.


#### Triggering Events
- Figure out in code whats the right place to trigger the event. And pass in the correct properties to be parsed by the Manger. Example: 

```sh
 /* Sending Events From trigger point */

class HomeViewController : UIViewController {

    @IBOutlet weak var actionBtn : UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ExampleEventManager.triggerEvent(AnalyticsTriggers.home_page_load,
                                        props : [])
    }
    
    @IBAction func actionBtnClicked( _ : UIButton) {
        ExampleEventManager.triggerEvent(AnalyticsTriggers.home_page_load,
                                        props : ["pageValue" : "YourValue"])
    }
}
```
If any of the clients want to append more properties thats upto them.
