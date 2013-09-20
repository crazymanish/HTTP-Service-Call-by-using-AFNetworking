//
//  HttpServiceCall.h
//
//
//  Created by Manish Rathi on 02/08/13.
//  Copyright (c) 2013 Manish Rathi. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.



#import <Foundation/Foundation.h>
#import "AFHTTPClient.h"
#import "AFNetworking.h"
#import "AFDownloadRequestOperation.h"
#import "AFImageRequestOperation.h"

@class AFHTTPRequestOperation;
typedef void (^JSONResponseBlock)(NSDictionary* json);
typedef void (^DownloadResponseBlock)(id data);
typedef void (^ImageDownloadResponseBlock)(UIImage *image,id data);

@protocol HttpServiceCallDelegate
@optional
-(void)updateDownloadProgress:(float)progressValue ofURL:(NSURL*)url;
-(void)internetStatusChanged:(AFNetworkReachabilityStatus)status;
@end

@interface HttpServiceCall : AFHTTPClient

@property (strong,nonatomic) NSOperationQueue *queue;
@property (strong,nonatomic) NSOperationQueue *downloadQueue;

+(HttpServiceCall*)instance;

//@HTTP-Service Operations
-(void)callServiceWithParams:(NSDictionary*)params methodType:(NSString*)method servicePath:(NSString*)path onCompletion:(JSONResponseBlock)completionBlock;
-(void)cancelAllHttpOperations;

//@IMAGE-Download
-(void)downloadImageWithUrl:(NSURL*)url withDelegate:(id)delegate onCompletion:(ImageDownloadResponseBlock)completionBlock;

//@Download Operations
-(void)downloadFileWithUrl:(NSURL*)url downLoadPath:(NSString*)path withDelegate:(id)delegate onCompletion:(DownloadResponseBlock)completionBlock;
-(void)pauseAllDownloadOperations;
-(void)resumeAllDownloadOperations;
-(void)cancelAllDownloadOperations;
-(void)resumeDownloadOperationWithURL:(NSURL *)url;
-(void)pauseDownloadOperationWithURL:(NSURL *)url;
-(void)cancelDownloadOperationWithURL:(NSURL *)url;

- (BOOL)clearAFNetworkingInCompleteDownloadCache;
@end