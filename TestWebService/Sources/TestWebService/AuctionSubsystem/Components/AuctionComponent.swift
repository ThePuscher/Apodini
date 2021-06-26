//
//  AuctionComponent.swift
//
//
//  Created by Paul Schmiedmayer on 1/19/21.
//

import Apodini
import ApodiniExtension


struct AuctionComponent: Component {
    var content: some Component {
        Group("auction") {
            Auction()
                .response(EmojiTransformer(emojis: "🤑", growth: 2))
        }
    }
}
