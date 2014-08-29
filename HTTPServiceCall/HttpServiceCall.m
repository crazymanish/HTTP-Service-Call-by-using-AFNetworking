//
//  HttpServiceCall.m
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

#import "HttpServiceCall.h"
#define kImageMimeType @"image/png"
#define kVideoMimeType @"video/quicktime"
#define kVideo @"video"
#define kImage @"image"
#define kPOST @"POST"
#define kHostUrl @"www.abc.com"  //You need to change this based on your server url.
@implementation HttpServiceCall
@synthesize queue,downloadQueue;
static HttpServiceCall *sharedInstance = nil;

#pragma mark - GET Instance
+(HttpServiceCall*)instance {
    @synchronized(self){
		if(!sharedInstance){
			sharedInstance = [[self alloc] initWithBaseURL:[NSURL URLWithString:kHostUrl]];
		}
	}
	return sharedInstance;
}

#pragma mark - init
-(HttpServiceCall*)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (self != nil) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
        [self setDefaultHeader:@"Accept" value:@"application/json"];
        queue=[[NSOperationQueue alloc] init];
        downloadQueue=[[NSOperationQueue alloc] init];
        
        //@Manish ---- will be useful for Internet-Connection Checking
	  //You might need to import the framework.If Error
        __block HttpServiceCall * __weak weakSelf=self;
        [self setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            [weakSelf internetConnectionChanged:status];
        }];
    }
    return self;
}

#pragma mark - InterNet Connection Handler
-(void)internetConnectionChanged:(AFNetworkReachabilityStatus)status{
    if (status==AFNetworkReachabilityStatusNotReachable) {
        //DebugLog(@"InterNet NotReachable.");
    }else if (status==AFNetworkReachabilityStatusReachableViaWiFi) {
        //DebugLog(@"InterNet Wifi is Avaliable.");
    }else if (status==AFNetworkReachabilityStatusReachableViaWWAN) {
        //DebugLog(@"InterNet 3G is Avaliable.");
    }
}


#pragma mark - Call HTTP-Service
-(void)callServiceWithParams:(NSDictionary*)params methodType:(NSString*)method servicePath:(NSString*)path onCompletion:(JSONResponseBlock)completionBlock {
    NSMutableURLRequest *apiRequest =nil;
    if ([method isEqualToString:kPOST]) {
        apiRequest=[self multipartFormRequestWithMethod:method path:path parameters:params constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
            NSData* uploadFileData = nil;
            if([params objectForKey:kVideo]!=nil && [[params objectForKey:kVideo] length]>0){
                uploadFileData =[NSData dataWithContentsOfURL:[NSURL URLWithString:[params objectForKey:kVideo]]];
                if (uploadFileData) {
                    [formData appendPartWithFileData:uploadFileData name:kVideo fileName:[params objectForKey:kVideo] mimeType:kVideoMimeType];
                }
            }else if ([params objectForKey:kImage]!=nil) {
                UIImage *image=[UIImage imageWithContentsOfFile:[params objectForKey:kImage]];
                uploadFileData = UIImagePNGRepresentation(image);
                if (uploadFileData) {
                    [formData appendPartWithFileData:uploadFileData name:kImage fileName:[params objectForKey:kImage] mimeType:kImageMimeType];
                }
            }
        }];
    }else{
        apiRequest=[self requestWithMethod:method path:path parameters:params];
    }
    
    AFJSONRequestOperation* operation = [[AFJSONRequestOperation alloc] initWithRequest: apiRequest];    
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        //  //DebugLog(@"RESPONSE = %@",responseObject);
        completionBlock(responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //DebugLog(@"RESPONSE Error= %@",error);
        completionBlock(nil);
    }];
    
    [self.queue addOperation:operation];
}

#pragma mark -Cancel All HTTP-Operations
-(void)cancelAllHttpOperations{
    for (NSOperation *operation in [self.queue operations]) {
        //DebugLog(@"Options is in AFNetworking :%@",operation);
        if ([operation isKindOfClass:[AFHTTPRequestOperation class]]) {
            [operation cancel];
        }
    }
}


#pragma mark - DownLoad File with Progress
-(void)downloadFileWithUrl:(NSURL*)url downLoadPath:(NSString*)path withDelegate:(id)delegate onCompletion:(DownloadResponseBlock)completionBlock{
    
    if ([self checkUrl_into_downloadQueue:url]) {
        [self resumeDownloadOperationWithURL:url];
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFDownloadRequestOperation *operation = [[AFDownloadRequestOperation alloc] initWithRequest:request targetPath:path shouldResume:YES];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        //  //DebugLog(@"Successfully downloaded file to %@", path);
        completionBlock(responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         //DebugLog(@"Error: %@", error);
        completionBlock(nil);
    }];
    
    __block AFDownloadRequestOperation * __weak op=operation;
    if (delegate!=nil) {
        [operation setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
            NSNumber *received = [NSNumber numberWithLongLong:totalBytesRead];
            NSNumber *total = [NSNumber numberWithLongLong:totalBytesExpectedToReadForFile];
            float percentage=([received floatValue]/[total floatValue]);
            
//            //DebugLog(@"%@",[NSString stringWithFormat:@"File-Downloading= %.2f%%",percentage*100]);
            if (delegate && [delegate respondsToSelector:@selector(updateDownloadProgress:ofURL:)]) {
                [delegate updateDownloadProgress:percentage ofURL:op.request.URL];
            }
        }];
    }
    [self.downloadQueue addOperation:operation];
}


#pragma mark - DOWNLOAD Helper Functions
-(BOOL)checkUrl_into_downloadQueue:(NSURL *)url{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            if ([[(AFDownloadRequestOperation *)operation getOperationUrl].absoluteString isEqualToString:url.absoluteString]) {
                return YES;
            }
        }
    }
    
    return NO;
}


-(void)pauseAllDownloadOperations{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            [(AFDownloadRequestOperation *)operation pause];
        }
    }
}
-(void)resumeAllDownloadOperations{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            [(AFDownloadRequestOperation *)operation resume];
        }
    }
}
-(void)cancelAllDownloadOperations{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            [self deleteAFTempFile:[(AFDownloadRequestOperation *)operation tempPath]];
            [(AFDownloadRequestOperation *)operation cancel];
        }
    }
}
-(void)resumeDownloadOperationWithURL:(NSURL *)url{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            if ([[(AFDownloadRequestOperation *)operation getOperationUrl].absoluteString isEqualToString:url.absoluteString]) {
                [(AFDownloadRequestOperation *)operation resume];
            }
        }
    }
}
-(void)pauseDownloadOperationWithURL:(NSURL *)url{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            if ([[(AFDownloadRequestOperation *)operation getOperationUrl].absoluteString isEqualToString:url.absoluteString]) {
                [(AFDownloadRequestOperation *)operation pause];
            }
        }
    }
}
-(void)cancelDownloadOperationWithURL:(NSURL *)url{
    for (NSOperation *operation in [self.downloadQueue operations]) {
        //DebugLog(@"Operation is in AFDownloadRequestOperation :%@",operation);
        if ([operation isKindOfClass:[AFDownloadRequestOperation class]]) {
            if ([[(AFDownloadRequestOperation *)operation getOperationUrl].absoluteString isEqualToString:url.absoluteString]) {
                [self deleteAFTempFile:[(AFDownloadRequestOperation *)operation tempPath]];
                [(AFDownloadRequestOperation *)operation cancel];
            }
        }
    }
}

-(BOOL)deleteAFTempFile:(NSString *)tempPath{
    //Delete Zip-File
    NSError *error=nil;
    if ([[NSFileManager defaultManager] removeItemAtPath:tempPath error:&error]) {
        //DebugLog(@"\n\n\n\nRemove AF-TEMP File at-path=%@\n\n\n\n",tempPath);
    }else{
        //DebugLog(@"Error to remove AF-TEMP file=%@ \n error=%@",tempPath,error);
        return NO;
    }
    return YES;
}

#pragma mark - Clear AFNetworking InComplete Download-Cache
- (BOOL)clearAFNetworkingInCompleteDownloadCache{
    NSError *error;
	/* remove the cache directory contents */
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *file in [fileManager contentsOfDirectoryAtPath:[AFDownloadRequestOperation cacheFolder] error:&error]){
        NSString *filePath = [[AFDownloadRequestOperation cacheFolder] stringByAppendingPathComponent:file];
        BOOL fileDeleted = [fileManager removeItemAtPath:filePath error:&error];
        if (fileDeleted != YES || error != nil){
            //DebugLog(@"File Not deleted for : %@", filePath);
        }else{
            //DebugLog(@"File deleted for : %@", filePath);
        }
    }
    return YES;
}

#pragma mark - DownLoad Image with Progress
-(void)downloadImageWithUrl:(NSURL*)url withDelegate:(id)delegate onCompletion:(ImageDownloadResponseBlock)completionBlock{
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    AFImageRequestOperation *operation = [[AFImageRequestOperation alloc] initWithRequest:request];
    
    __block AFImageRequestOperation * __weak op=operation;
    
    // Set a download progress block for the operation
    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        NSNumber *received = [NSNumber numberWithLongLong:totalBytesRead];
        NSNumber *total = [NSNumber numberWithLongLong:totalBytesExpectedToRead];
        float percentage=([received floatValue]/[total floatValue])*100;
        
        //DebugLog(@"Image= %@ & download%%= %.0f",[[op.request.URL path] lastPathComponent],percentage);
        
        if (delegate && [delegate respondsToSelector:@selector(updateDownloadProgress:ofURL:)]) {
            [delegate updateDownloadProgress:percentage ofURL:op.request.URL];
        }
    }];
    
    // Set a completion block for the operation
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSData *imageData = UIImagePNGRepresentation(responseObject);
        completionBlock(responseObject,imageData);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        completionBlock(nil,nil);
    }];
    
    [self.downloadQueue addOperation:operation];
}
@end