/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXWebComponent.h"
#import "WXComponent_internal.h"
#import "WXUtility.h"
#import "WXHandlerFactory.h"
#import "WXURLRewriteProtocol.h"
#import "WXSDKEngine.h"

#import <WebKit/WebKit.h>

NSString * const WXWebViewMessageHandleName = @"WXHandle";

@interface WXWebViewMessageHandle : NSObject <WKScriptMessageHandler>

@property (weak, nonatomic) WXComponent *component;

@end

@implementation WXWebViewMessageHandle

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:WXWebViewMessageHandleName]) {
        NSDictionary *args = message.body;
        if (args && args.count < 2) {
            return;
        }
        NSDictionary *data = args[@"message"];
        NSString *origin = args[@"targetOrigin"];
        if (!data || !origin) {
            return;
        }
        NSDictionary *initDic = @{ @"type" : @"message",
                                   @"data" : data,
                                   @"origin" : origin
        };
        [self.component fireEvent:@"message" params:initDic];
    }
}

@end

@interface WXWebView : WKWebView

@end

@implementation WXWebView

- (void)dealloc
{
    if (self) { //!OCLint
//        self.delegate = nil;
    }
}

@end

@interface WXWebComponent ()<WKUIDelegate, WKNavigationDelegate>


@property (nonatomic, strong) WXWebView *webview;

@property (nonatomic, strong) NSString *url;

@property (nonatomic, strong) NSString *source;

// save source during this initialization
@property (nonatomic, strong) NSString *inInitsource;

@property (nonatomic, assign) BOOL startLoadEvent;

@property (nonatomic, assign) BOOL finishLoadEvent;

@property (nonatomic, assign) BOOL failLoadEvent;

@property (nonatomic, strong) WXWebViewMessageHandle *messageHandle;

@end

@implementation WXWebComponent

WX_EXPORT_METHOD(@selector(postMessage:))
WX_EXPORT_METHOD(@selector(goBack))
WX_EXPORT_METHOD(@selector(reload))
WX_EXPORT_METHOD(@selector(goForward))

- (instancetype)initWithRef:(NSString *)ref type:(NSString *)type styles:(NSDictionary *)styles attributes:(NSDictionary *)attributes events:(NSArray *)events weexInstance:(WXSDKInstance *)weexInstance
{
    if (self = [super initWithRef:ref type:type styles:styles attributes:attributes events:events weexInstance:weexInstance]) {
        self.url = attributes[@"src"];
        
        if(attributes[@"source"]){
            self.inInitsource = attributes[@"source"];
        }
        
    }
    return self;
}

- (UIView *)loadView {
    return [[WXWebView alloc] initWithFrame:CGRectZero configuration:[WKWebViewConfiguration new]];
}

- (void)viewDidLoad
{
    self.messageHandle = [[WXWebViewMessageHandle alloc] init];
    self.messageHandle.component = self;
    _webview = (WXWebView *)self.view;
    [_webview.configuration.userContentController addScriptMessageHandler:self.messageHandle name:WXWebViewMessageHandleName];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:@"window.postMessage = function (message, targetOrigin, transfer) {var info = {};if (message) {info['message'] = message;}if (targetOrigin) {info['targetOrigin'] = targetOrigin;}if (transfer) {info['transfer'] = transfer;}window.webkit.messageHandlers.WXHandle.postMessage(info);}" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [_webview.configuration.userContentController addUserScript:script];
    _webview.UIDelegate = self;
    _webview.navigationDelegate = self;
    _webview.configuration.allowsInlineMediaPlayback = YES;
    [_webview setBackgroundColor:[UIColor clearColor]];
    _webview.opaque = NO;
    
    self.source = _inInitsource;
    if (_url) {
        [self loadURL:_url];
    }
}

- (void)updateAttributes:(NSDictionary *)attributes
{
    if (attributes[@"src"]) {
        self.url = attributes[@"src"];
    }

    if (attributes[@"source"]) {
        self.inInitsource = attributes[@"source"];
        self.source = self.inInitsource;
    }
}

- (void)addEvent:(NSString *)eventName
{
    if ([eventName isEqualToString:@"pagestart"]) {
        _startLoadEvent = YES;
    }
    else if ([eventName isEqualToString:@"pagefinish"]) {
        _finishLoadEvent = YES;
    }
    else if ([eventName isEqualToString:@"error"]) {
        _failLoadEvent = YES;
    }
}

- (void)setUrl:(NSString *)url
{
    NSString* newURL = [url copy];
    WX_REWRITE_URL(url, WXResourceTypeLink, self.weexInstance)
    if (!newURL) {
        return;
    }
    
    if (![newURL isEqualToString:_url]) {
        _url = newURL;
        if (_url) {
            [self loadURL:_url];
        }
    }
}

- (void) setSource:(NSString *)source
{
    NSString *newSource=[source copy];
    if(!newSource || _url){
        return;
    }
    if(![newSource isEqualToString:_source]){
        _source=newSource;
        if(_source){
            [_webview loadHTMLString:_source baseURL:nil];
        }
    }
    
}

- (void)loadURL:(NSString *)url
{
    if (self.webview) {
        NSURLRequest *request =[NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        [self.webview loadRequest:request];
    }
}

- (void)reload
{
    [self.webview reload];
}

- (void)goBack
{
    if ([self.webview canGoBack]) {
        [self.webview goBack];
    }
}

- (void)goForward
{
    if ([self.webview canGoForward]) {
        [self.webview goForward];
    }
}

// This method will be abandoned slowly, use postMessage
- (void)notifyWebview:(NSDictionary *) data
{
    NSString *json = [WXUtility JSONString:data];
    NSString *code = [NSString stringWithFormat:@"(function(){var evt=null;var data=%@;if(typeof CustomEvent==='function'){evt=new CustomEvent('notify',{detail:data})}else{evt=document.createEvent('CustomEvent');evt.initCustomEvent('notify',true,true,data)}document.dispatchEvent(evt)}())", json];
    [self.webview evaluateJavaScript:code completionHandler:^(id _Nullable obj, NSError * _Nullable error) {
        
    }];
}

// Weex postMessage to web
- (void)postMessage:(NSDictionary *)data {
    WXSDKInstance *instance = [WXSDKEngine topInstance];

    NSString *bundleUrlOrigin = @"";

    if (instance.pageName) {
        NSString *bundleUrl = [instance.scriptURL absoluteString];
        NSURL *url = [NSURL URLWithString:bundleUrl];
        bundleUrlOrigin = [NSString stringWithFormat:@"%@://%@%@", url.scheme, url.host, url.port ? [NSString stringWithFormat:@":%@", url.port] : @""];
    }

    NSDictionary *initDic = @{
        @"type" : @"message",
        @"data" : data,
        @"origin" : bundleUrlOrigin
    };

    NSString *json = [WXUtility JSONString:initDic];

    NSString *code = [NSString stringWithFormat:@"(function (){window.dispatchEvent(new MessageEvent('message', %@));}())", json];
    [self.webview evaluateJavaScript:code completionHandler:^(id _Nullable obj, NSError * _Nullable error) {
        
    }];
}

#pragma mark Webview Delegate

- (void)getBaseInfo:(void (^)(NSMutableDictionary<NSString *, id> * baseInfo))callback {
    [self.webview evaluateJavaScript:@"document.title" completionHandler:^(NSString * _Nullable title, NSError * _Nullable error) {
        NSMutableDictionary<NSString *, id> *info = [NSMutableDictionary new];
        [info setObject:self.webview.URL.absoluteString ?: @"" forKey:@"url"];
        [info setObject:title ?: @"" forKey:@"title"];
        [info setObject:@(self.webview.canGoBack) forKey:@"canGoBack"];
        [info setObject:@(self.webview.canGoForward) forKey:@"canGoForward"];
        !callback ?: callback(info);
    }];
}

#pragma mark - WKUIDelegate

/// alert弹框
/// @param webView webView
/// @param message 消息
/// @param frame 框架信息
/// @param completionHandler 完成回调
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self.weexInstance.viewController presentViewController:alert animated:YES completion:^{
        
    }];
}

/// confirm弹框
/// @param webView webView
/// @param message 消息
/// @param frame 框架信息
/// @param completionHandler 完成回调
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];
    [self.weexInstance.viewController presentViewController:alert animated:YES completion:^{
        
    }];
}

/// prompt弹框
/// @param webView webView
/// @param prompt 消息
/// @param defaultText 默认内容
/// @param frame 框架信息
/// @param completionHandler 完成回调
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:prompt preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
        textField.placeholder = prompt;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alert.textFields.firstObject.text);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(nil);
    }]];
    [self.weexInstance.viewController presentViewController:alert animated:YES completion:^{
        
    }];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (_finishLoadEvent) {
        [self getBaseInfo:^(NSMutableDictionary<NSString *,id> *baseInfo) {
            [self fireEvent:@"pagefinish" params:baseInfo domChanges:@{@"attrs": @{@"src":self.webview.URL.absoluteString}}];
        }];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (_failLoadEvent) {
        
        [self getBaseInfo:^(NSMutableDictionary<NSString *,id> *data) {
            [data setObject:[error localizedDescription] forKey:@"errorMsg"];
            [data setObject:[NSString stringWithFormat:@"%ld", (long)error.code] forKey:@"errorCode"];
            
            NSString * urlString = error.userInfo[NSURLErrorFailingURLStringErrorKey];
            if (urlString) {
                // webview.request may not be the real error URL, must get from error.userInfo
                [data setObject:urlString forKey:@"url"];
                if (![urlString hasPrefix:@"http"]) {
                    return;
                }
            }
            [self fireEvent:@"error" params:data];
        }];
        
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (_startLoadEvent) {
        NSMutableDictionary<NSString *, id> *data = [NSMutableDictionary new];
        [data setObject:navigationAction.request.URL.absoluteString ?:@"" forKey:@"url"];
        [self fireEvent:@"pagestart" params:data];
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
