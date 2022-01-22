//
//  Message.swift
//  LetsChat
//
//  Created by paige on 2022/01/22.
//

import Foundation

struct Message: Codable {
    
    var id: String?
    var text: String = ""
    var username: String = ""
    var roomId: String = ""
    var messageDate: Date = Date()
    
    init(vs: MessageViewState) {
        text = vs.message
        username = vs.username
        roomId = vs.roomId
    }
    
}
