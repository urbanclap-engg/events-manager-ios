//
//  AnalyticsClientProtocol.swift
//  AnalyticsClientManager
//
//  Created by Kanav Arora on 07/06/16.
//  Copyright © 2016 Kanav Arora. All rights reserved.
//

import Foundation

@objc public protocol AnalyticsClientProtocol {
    func setup()
    func sendEvent(_ props:[String: AnyObject])
}
