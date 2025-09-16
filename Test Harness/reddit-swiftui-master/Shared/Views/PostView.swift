//
//  PostView.swift
//  Reddit
//
//  Created by Carson Katri on 7/21/19.
//  Copyright © 2019 Carson Katri. All rights reserved.
//

import SwiftUI
import Request
import NewRelic

struct PostView: View {
    let post: Post
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                #if os(iOS)
                Text(post.title)
                    .pathLeaf()
                    .font(.headline)
                    .lineLimit(1)
                    .trackable()
                    .decompile()
                #elseif os(macOS)
                Text(post.title)
                    .bold()
                #endif
                /// Body preview
                Group {
                    if post.url.contains("reddit") {
                        Text(post.selftext != "" ? post.selftext : " ")
                            .pathLeaf()
                            .trackable()
                            .decompile()
                    } else {
                        Text(post.url)
                            .pathLeaf()
                            .trackable()
                            .decompile()
                    }
                }
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(1)
                /// Metadata for the post
                MetadataView(post: post, spaced: false)
                    .font(.caption)
                    .opacity(0.75)
                    .trackable()
                    .decompile()
            }
            if post.thumbnail != "self" {
                Spacer()
                // TODO: Handle Spacer path
                  //  .pathLeaf()
                    .trackable()
                    .decompile()
                RequestImage(Url(post.thumbnail))
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50, alignment: .center)
                    .clipped()
                    .cornerRadius(5.0)
            }
        }
    }
}

#if DEBUG
struct PostView_Previews: PreviewProvider {
    static var previews: some View {
        PostView(post: Post.example)
    }
}
#endif
