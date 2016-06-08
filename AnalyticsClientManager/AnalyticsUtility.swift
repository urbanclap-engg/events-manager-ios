//
//  AnalyticsUtility.swift
//  AnalyticsClientManager
//
//  Created by Kanav Arora on 06/06/16.
//  Copyright © 2016 Kanav Arora. All rights reserved.
//

import Foundation
import CSwiftV

func parseCSVFileIntoAnalyticEvents(bundle: NSBundle?, csvFile: String?) -> [String: [String: String]]{
    let keywordTrigger = "trigger"
    
    let fileLocation = bundle?.pathForResource(csvFile, ofType: "csv")
    let textFile : String
    do
    {
        textFile = try String(contentsOfFile: fileLocation!)
    }
    catch
    {
        print("Error: parsing csv file: \(csvFile)")
        textFile = ""
    }
    let csv = CSwiftV(string: textFile)
    let headers = csv.headers
    if (!headers.contains(keywordTrigger)) {
        print("Error: csv file: \(csvFile) needs to have trigger column")
    }
    let keyedRows = csv.keyedRows
    if (keyedRows == nil) {
        return [:]
    }
    var rtn = [String: [String: String]]()
    
    for keyedRow in keyedRows! {
        if ((keyedRow[keywordTrigger] ?? "").isEmpty) { // check for empty string too
            print("Error: csv file: \(csvFile) has missing trigger column entry for a row")
        }
        let trigger = keyedRow[keywordTrigger]!
        var tmpKeyedRow = keyedRow
        tmpKeyedRow.removeValueForKey(keywordTrigger)
        rtn[trigger] = tmpKeyedRow
    }
    return rtn
}
