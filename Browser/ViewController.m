//
//  ViewController.m
//  Browser
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015
//  Copyright © 2015 High Caffeine Content. All rights reserved.
//

#import "ViewController.h"

typedef struct _Input
{
    CGFloat x;
    CGFloat y;
} Input;


@interface ViewController ()
{
    UIImageView *cursorView;
    UIActivityIndicatorView *loadingSpinner;
    Input input;
    NSString *requestURL;
    NSString *previousURL;
}

@property id webview;
@property (strong) CADisplayLink *link;
@property (strong, nonatomic) GCController *controller;
@property BOOL cursorMode;
@property BOOL displayedHintsOnLaunch;
@property BOOL scrollViewAllowBounces;
@property CGPoint lastTouchLocation;
@property NSUInteger textFontSize;

@end

@implementation ViewController {
    UITapGestureRecognizer *touchSurfaceDoubleTapRecognizer;
    UITapGestureRecognizer *playPauseOrMenuDoubleTapRecognizer;
}

-(void) webViewDidStartLoad:(id)webView {
    //[self.view bringSubviewToFront:loadingSpinner];
    if (![previousURL isEqualToString:requestURL]) {
        [loadingSpinner startAnimating];
    }
    previousURL = requestURL;
}

-(void) webViewDidFinishLoad:(id)webView {
    [loadingSpinner stopAnimating];
    //[self.view bringSubviewToFront:loadingSpinner];
    NSString *theTitle=[webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    NSURLRequest *request = [webView request];
    NSString *currentURL = request.URL.absoluteString;
    NSArray *toSaveItem = [NSArray arrayWithObjects:currentURL, theTitle, nil];
    NSMutableArray *historyArray = [NSMutableArray arrayWithObjects:toSaveItem, nil];
    if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] != nil) {
        NSMutableArray *savedArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] mutableCopy];
        if ([savedArray count] > 0) {
            if ([savedArray[0][0] isEqualToString: currentURL]) {
                [historyArray removeObjectAtIndex:0];
            }
        }
        [historyArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"]];
    }
    while ([historyArray count] > 100) {
        [historyArray removeLastObject];
    }

    [[NSUserDefaults standardUserDefaults] setObject:historyArray forKey:@"HISTORY"];
}

-(void)viewDidAppear:(BOOL)animated {
    loadingSpinner.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"savedURLtoReopen"]]]];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"savedURLtoReopen"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else if ([_webview request] == nil) {
        //[self requestURLorSearchInput];
        [self loadHomePage];
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DontShowHintsOnLaunch"] && !_displayedHintsOnLaunch) {
        [self showHintsAlert];
    }
    _displayedHintsOnLaunch = YES;
}

-(void)loadHomePage {
    if ([[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"] != nil) {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSUserDefaults standardUserDefaults] stringForKey:@"homepage"]]]];
    }
    else {
        [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: @"http://www.google.de"]]];
    }
}

-(void)viewDidLoad {
    _scrollViewAllowBounces = NO;
    [super viewDidLoad];
    touchSurfaceDoubleTapRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleTouchSurfaceDoubleTap:)];
    touchSurfaceDoubleTapRecognizer.numberOfTapsRequired = 2;
    touchSurfaceDoubleTapRecognizer.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypeSelect]];
    [self.view addGestureRecognizer:touchSurfaceDoubleTapRecognizer];
    
    playPauseOrMenuDoubleTapRecognizer = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleDoubleTapMenuOrPlayPause:)];
    playPauseOrMenuDoubleTapRecognizer.numberOfTapsRequired = 2;
    playPauseOrMenuDoubleTapRecognizer.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypePlayPause], [NSNumber numberWithInteger:UIPressTypeMenu]];
    [self.view addGestureRecognizer:playPauseOrMenuDoubleTapRecognizer];
    
    cursorView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
    cursorView.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    cursorView.image = [UIImage imageNamed:@"Cursor"];
    cursorView.backgroundColor = [UIColor clearColor];
    cursorView.hidden = YES;
    
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    longPress.allowedPressTypes = @[[NSNumber numberWithInteger:UIPressTypePlayPause]];
    [self.view addGestureRecognizer:longPress];
    
    self.webview = [[NSClassFromString(@"UIWebView") alloc] initWithFrame:[UIScreen mainScreen].bounds];
    //[self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]]];
    
    [self.view addSubview:self.webview];
    [self.view addSubview:cursorView];
    
    [self.webview setDelegate:self];
    UIScrollView *scrollView = [self.webview scrollView];

    scrollView.bounces = _scrollViewAllowBounces;
    scrollView.panGestureRecognizer.allowedTouchTypes = @[ @(UITouchTypeIndirect) ];
    
    loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    loadingSpinner.center = CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), CGRectGetMidY([UIScreen mainScreen].bounds));
    loadingSpinner.tintColor = [UIColor blackColor];
    loadingSpinner.hidesWhenStopped = true;
    //[loadingSpinner startAnimating];
    [self.view addSubview:loadingSpinner];
    [self.view bringSubviewToFront:loadingSpinner];
    //ENABLE CURSOR MODE INITIALLY
    self.cursorMode = YES;

    scrollView.scrollEnabled = NO;
    
    [self.webview setUserInteractionEnabled:NO];
    [self.webview setScalesPageToFit:NO];

    cursorView.hidden = NO;
    self.textFontSize = 100;
}

-(void)handleDoubleTapMenuOrPlayPause:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"Menü"
                                              message:@""
                                              preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *loadHomePageAction = [UIAlertAction
                                             actionWithTitle:@"Zur Startseite"
                                             style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action)
                                             {
                                                 [self loadHomePage];
                                             }];
        UIAlertAction *setHomePageAction = [UIAlertAction
                                            actionWithTitle:@"Aktuelle Seite zur Startseite machen"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action)
                                            {
                                                NSURLRequest *request = [_webview request];
                                                if (request != nil) {
                                                    if (![request.URL.absoluteString isEqual:@""]) {
                                                        [[NSUserDefaults standardUserDefaults] setObject:request.URL.absoluteString forKey:@"homepage"];
                                                    }
                                                }
                                            }];
        UIAlertAction *showHintsAction = [UIAlertAction
                                          actionWithTitle:@"Bedienungsanleitung"
                                          style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action)
                                          {
                                              [self showHintsAlert];
                                          }];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Abbrechen"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action)
                                       {
                                       }];
        UIAlertAction *viewFavoritesAction = [UIAlertAction
                                              actionWithTitle:@"Favoriten"
                                              style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action)
                                              {
                                                  NSArray *indexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"];
                                                  UIAlertController *historyAlertController = [UIAlertController
                                                                                               alertControllerWithTitle:@"Favoriten"
                                                                                               message:@""
                                                                                               preferredStyle:UIAlertControllerStyleAlert];
                                                  UIAlertAction *editFavoritesAction = [UIAlertAction
                                                                                        actionWithTitle:@"Favoriten löschen"
                                                                                        style:UIAlertActionStyleDestructive
                                                                                        handler:^(UIAlertAction *action)
                                                                                        {
                                                                                            NSArray *editingIndexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"];
                                                                                            UIAlertController *editHistoryAlertController = [UIAlertController
                                                                                                                                             alertControllerWithTitle:@"Favoriten löschen"
                                                                                                                                             message:@"Favoriten zum Löschen auswählen"
                                                                                                                                             preferredStyle:UIAlertControllerStyleAlert];
                                                                                            if (editingIndexableArray != nil) {
                                                                                                for (int i = 0; i < [editingIndexableArray count]; i++) {
                                                                                                    NSString *objectTitle = editingIndexableArray[i][1];
                                                                                                    NSString *objectSubtitle = editingIndexableArray[i][0];
                                                                                                    if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                                                                        if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                                                                            objectTitle = objectSubtitle;
                                                                                                        }
                                                                                                        UIAlertAction *favoriteItem = [UIAlertAction
                                                                                                                                       actionWithTitle:objectTitle
                                                                                                                                       style:UIAlertActionStyleDefault
                                                                                                                                       handler:^(UIAlertAction *action)
                                                                                                                                       {
                                                                                                                                           NSMutableArray *editingArray = [editingIndexableArray mutableCopy];
                                                                                                                                           [editingArray removeObjectAtIndex:i];
                                                                                                                                           NSArray *toStoreArray = editingArray;
                                                                                                                                           [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"FAVORITES"];
                                                                                                                                           [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                                                                       }];
                                                                                                        [editHistoryAlertController addAction:favoriteItem];
                                                                                                    }
                                                                                                }
                                                                                            }
                                                                                            [editHistoryAlertController addAction:cancelAction];
                                                                                            [self presentViewController:editHistoryAlertController animated:YES completion:nil];
                                                                                            
                                                                                        }];
                                                  UIAlertAction *addToFavoritesAction = [UIAlertAction
                                                                                         actionWithTitle:@"Aktuelle Seite zu Favoriten hinzufügen"
                                                                                         style:UIAlertActionStyleDefault
                                                                                         handler:^(UIAlertAction *action)
                                                                                         {
                                                                                             NSURLRequest *request = [self.webview request];
                                                                                             NSString *theTitle=[_webview stringByEvaluatingJavaScriptFromString:@"document.title"];
                                                                                             NSString *currentURL = request.URL.absoluteString;
                                                                                             UIAlertController *favoritesAddToController = [UIAlertController
                                                                                                                                            alertControllerWithTitle:@"Favoriten benennen"
                                                                                                                                            message:currentURL
                                                                                                                                            preferredStyle:UIAlertControllerStyleAlert];
                                                                                             
                                                                                             [favoritesAddToController addTextFieldWithConfigurationHandler:^(UITextField *textField)
                                                                                              {
                                                                                                  textField.keyboardType = UIKeyboardTypeDefault;
                                                                                                  textField.placeholder = @"Name";
                                                                                                  textField.text = theTitle;
                                                                                                  textField.textColor = [UIColor blackColor];
                                                                                                  textField.backgroundColor = [UIColor whiteColor];
                                                                                                  [textField setReturnKeyType:UIReturnKeyDone];
                                                                                                  [textField addTarget:self
                                                                                                                action:@selector(alertTextFieldShouldReturn:)
                                                                                                      forControlEvents:UIControlEventEditingDidEnd];
                                                                                                  
                                                                                              }];
                                                                                             
                                                                                             UIAlertAction *saveAction = [UIAlertAction
                                                                                                                          actionWithTitle:@"Speichern"
                                                                                                                          style:UIAlertActionStyleDestructive
                                                                                                                          handler:^(UIAlertAction *action)
                                                                                                                          {
                                                                                                                              UITextField *urltextfield = favoritesAddToController.textFields[0];
                                                                                                                              NSString *toMod = urltextfield.text;
                                                                                                                              if ([toMod isEqualToString:@""]) {
                                                                                                                                  toMod = currentURL;
                                                                                                                              }
                                                                                                                              NSArray *toSaveItem = [NSArray arrayWithObjects:currentURL, theTitle, nil];
                                                                                                                              NSMutableArray *historyArray = [NSMutableArray arrayWithObjects:toSaveItem, nil];
                                                                                                                              if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] != nil) {
                                                                                                                                  historyArray = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] mutableCopy];
                                                                                                                                  [historyArray addObject:toSaveItem];
                                                                                                                              }
                                                                                                                              NSArray *toStoreArray = historyArray;
                                                                                                                              [[NSUserDefaults standardUserDefaults] setObject:toStoreArray forKey:@"FAVORITES"];
                                                                                                                              [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                                                              
                                                                                                                          }];
                                                                                             [favoritesAddToController addAction:saveAction];
                                                                                             [favoritesAddToController addAction:cancelAction];
                                                                                             [self presentViewController:favoritesAddToController animated:YES completion:nil];
                                                                                             //UITextField *textFieldAlert = favoritesAddToController.textFields[0];
                                                                                             //[textFieldAlert becomeFirstResponder];
                                                                                             
                                                                                         }];
                                                  if (indexableArray != nil) {
                                                      for (int i = 0; i < [indexableArray count]; i++) {
                                                          NSString *objectTitle = indexableArray[i][1];
                                                          NSString *objectSubtitle = indexableArray[i][0];
                                                          if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                              if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                                  objectTitle = objectSubtitle;
                                                              }
                                                              UIAlertAction *favoriteItem = [UIAlertAction
                                                                                             actionWithTitle:objectTitle
                                                                                             style:UIAlertActionStyleDefault
                                                                                             handler:^(UIAlertAction *action)
                                                                                             {
                                                                                                 [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: indexableArray[i][0]]]];
                                                                                             }];
                                                              [historyAlertController addAction:favoriteItem];
                                                          }
                                                      }
                                                  }
                                                  if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] != nil) {
                                                      if ([[[NSUserDefaults standardUserDefaults] arrayForKey:@"FAVORITES"] count] > 0) {
                                                          [historyAlertController addAction:editFavoritesAction];
                                                      }
                                                  }
                                                  [historyAlertController addAction:addToFavoritesAction];
                                                  [historyAlertController addAction:cancelAction];
                                                  [self presentViewController:historyAlertController animated:YES completion:nil];
                                              }];
        UIAlertAction *viewHistoryAction = [UIAlertAction
                                            actionWithTitle:@"Verlauf"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action)
                                            {
                                                NSArray *indexableArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"];
                                                UIAlertController *historyAlertController = [UIAlertController
                                                                                             alertControllerWithTitle:@"Verlauf"
                                                                                             message:@""
                                                                                             preferredStyle:UIAlertControllerStyleAlert];
                                                UIAlertAction *clearHistoryAction = [UIAlertAction
                                                                                     actionWithTitle:@"Verlauf löschen"
                                                                                     style:UIAlertActionStyleDestructive
                                                                                     handler:^(UIAlertAction *action)
                                                                                     {
                                                                                         [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"HISTORY"];
                                                                                         [[NSUserDefaults standardUserDefaults] synchronize];
                                                                                         
                                                                                     }];
                                                if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"HISTORY"] != nil) {
                                                    [historyAlertController addAction:clearHistoryAction];
                                                }
                                                for (int i = 0; i < [indexableArray count]; i++) {
                                                    NSString *objectTitle = indexableArray[i][1];
                                                    NSString *objectSubtitle = indexableArray[i][0];
                                                    if (![[objectSubtitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                        if ([[objectTitle stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
                                                            objectTitle = objectSubtitle;
                                                        }
                                                        else {
                                                            objectTitle = [NSString stringWithFormat:@"%@ - %@",objectTitle,objectSubtitle ];
                                                        }
                                                        UIAlertAction *historyItem = [UIAlertAction
                                                                                      actionWithTitle:objectTitle
                                                                                      style:UIAlertActionStyleDefault
                                                                                      handler:^(UIAlertAction *action)
                                                                                      {
                                                                                          [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString: indexableArray[i][0]]]];
                                                                                      }];
                                                        [historyAlertController addAction:historyItem];
                                                    }
                                                }
                                                [historyAlertController addAction:cancelAction];
                                                [self presentViewController:historyAlertController animated:YES completion:nil];
                                            }];
        UIAlertAction *mobileModeAction = [UIAlertAction
                                           actionWithTitle:@"Zur Mobilansicht wechseln"
                                           style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action)
                                           {
                                               NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.2.7 (KHTML, like Gecko) Version/9.0 Mobile/12B410 Safari/601.2.7", @"UserAgent", nil];
                                               [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
                                               [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"MobileMode"];
                                               [[NSUserDefaults standardUserDefaults] synchronize];
                                               NSURLRequest *request = [_webview request];
                                               if (request != nil) {
                                                   if (![request.URL.absoluteString isEqual:@""]) {
                                                       [[NSUserDefaults standardUserDefaults] setObject:request.URL.absoluteString forKey:@"savedURLtoReopen"];
                                                   }
                                               }
                                               exit(0);
                                               
                                           }];
        UIAlertAction *desktopModeAction = [UIAlertAction
                                            actionWithTitle:@"Zur Desktopansicht wechseln"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action)
                                            {
                                                NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/601.2.7 (KHTML, like Gecko) Version/9.0.1 Safari/601.2.7", @"UserAgent", nil];
                                                [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
                                                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"MobileMode"];
                                                NSURLRequest *request = [_webview request];
                                                if (request != nil) {
                                                    if (![request.URL.absoluteString isEqual:@""]) {
                                                        [[NSUserDefaults standardUserDefaults] setObject:request.URL.absoluteString forKey:@"savedURLtoReopen"];
                                                    }
                                                }
                                                exit(0);
                                            }];
        UIAlertAction *clearCacheAction = [UIAlertAction
                                           actionWithTitle:@"Cache leeren"
                                           style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction *action)
                                           {
                                               [[NSURLCache sharedURLCache] removeAllCachedResponses];
                                               [[NSUserDefaults standardUserDefaults] synchronize];
                                               previousURL = @"";
                                               [self.webview reload];
                                               
                                           }];
        UIAlertAction *clearCookiesAction = [UIAlertAction
                                             actionWithTitle:@"Cookies löschen"
                                             style:UIAlertActionStyleDestructive
                                             handler:^(UIAlertAction *action)
                                             {
                                                 NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                                                 for (NSHTTPCookie *cookie in [storage cookies]) {
                                                     [storage deleteCookie:cookie];
                                                 }
                                                 [[NSUserDefaults standardUserDefaults] synchronize];
                                                 previousURL = @"";
                                                 [self.webview reload];
                                                 
                                             }];
        
        UIAlertAction *increaseFontSizeAction = [UIAlertAction
                                             actionWithTitle:@"Schrift vergrößern"
                                             style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action)
                                             {
                                                 self.textFontSize = (self.textFontSize < 160) ? self.textFontSize +5 : self.textFontSize;
                                                 
                                                 NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%lu%%'",
                                                                       (unsigned long)self.textFontSize];
                                                 [self.webview stringByEvaluatingJavaScriptFromString:jsString];
                                             }];
        
        UIAlertAction *decreaseFontSizeAction = [UIAlertAction
                                                 actionWithTitle:@"Schrift verkleinern"
                                                 style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action)
                                                 {
                                                     self.textFontSize = (self.textFontSize > 50) ? self.textFontSize -5 : self.textFontSize;
                                                     
                                                     NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%lu%%'",
                                                                           (unsigned long)self.textFontSize];
                                                     [self.webview stringByEvaluatingJavaScriptFromString:jsString];
                                                 }];
        
        UIAlertAction *scalePageToFitAction = [UIAlertAction
                                                 actionWithTitle:@"Seite an Bildschirm anpassen"
                                                 style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action)
                                                 {
                                                     if ([self.webview scalesPageToFit] == YES) {
                                                         [self.webview setScalesPageToFit: NO];
                                                     } else {
                                                         [self.webview setScalesPageToFit: YES];
                                                         [self.webview setContentMode: UIViewContentModeScaleAspectFit];
                                                     }
                                                     [self.webview reload];
                                                 }];
        /*
         UIAlertAction *reloadAction = [UIAlertAction
         actionWithTitle:@"Reload Page"
         style:UIAlertActionStyleDefault
         handler:^(UIAlertAction *action)
         {
         _inputViewVisible = NO;
         previousURL = @"";
         [self.webview reload];
         }];
         if (_webview.request != nil) {
         if (![_webview.request.URL.absoluteString  isEqual: @""]) {
         [alertController addAction:reloadAction];
         }
         }
         */
        [alertController addAction:viewFavoritesAction];
        [alertController addAction:viewHistoryAction];
        [alertController addAction:loadHomePageAction];
        [alertController addAction:setHomePageAction];
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MobileMode"]) {
            [alertController addAction:desktopModeAction];
        }
        else {
            [alertController addAction:mobileModeAction];
        }
        [alertController addAction:clearCacheAction];
        [alertController addAction:clearCookiesAction];
        [alertController addAction:showHintsAction];
        [alertController addAction:increaseFontSizeAction];
        [alertController addAction:decreaseFontSizeAction];
        [alertController addAction:scalePageToFitAction];
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

-(void)handleTouchSurfaceDoubleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self toggleMode];
    }
}

-(void)requestURLorSearchInput {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Adresse oder Suchbegriff eingeben"
                                          message:@""
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField)
     {
         textField.keyboardType = UIKeyboardTypeURL;
         textField.placeholder = @"Adresse oder Suchbegriff";
         textField.textColor = [UIColor blackColor];
         textField.backgroundColor = [UIColor whiteColor];
         [textField setReturnKeyType:UIReturnKeyDone];
         [textField addTarget:self
                       action:@selector(alertTextFieldShouldReturn:)
             forControlEvents:UIControlEventEditingDidEnd];
         
     }];
    
    UIAlertAction *goAction = [UIAlertAction
                               actionWithTitle:@"Zur Webseite navigieren"
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                   UITextField *urltextfield = alertController.textFields[0];
                                   NSString *toMod = urltextfield.text;
                                   /*
                                    if ([toMod containsString:@" "] || ![temporaryURL containsString:@"."]) {
                                    toMod = [toMod stringByReplacingOccurrencesOfString:@" " withString:@"+"];
                                    toMod = [toMod stringByReplacingOccurrencesOfString:@"." withString:@"+"];
                                    toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                    toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                    toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                    toMod = [toMod stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
                                    if (toMod != nil) {
                                    [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/search?q=%@", toMod]]]];
                                    }
                                    else {
                                    [self requestURLorSearchInput];
                                    }
                                    }
                                    else {
                                    */
                                   if (![toMod isEqualToString:@""]) {
                                       if ([toMod containsString:@"http://"] || [toMod containsString:@"https://"]) {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@", toMod]]]];
                                       }
                                       else {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", toMod]]]];
                                       }
                                   }
                                   else {
                                       [self requestURLorSearchInput];
                                   }
                                   //}
                                   
                               }];
    UIAlertAction *searchAction = [UIAlertAction
                                   actionWithTitle:@"Mit Google suchen"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       UITextField *urltextfield = alertController.textFields[0];
                                       NSString *toMod = urltextfield.text;
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@" " withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"." withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
                                       toMod = [toMod stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
                                       if (toMod != nil) {
                                           [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.de/search?q=%@", toMod]]]];
                                       }
                                       else {
                                           [self requestURLorSearchInput];
                                       }
                                   }];
    
    UIAlertAction *reloadAction = [UIAlertAction
                                   actionWithTitle:@"Seite aktualisieren"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       previousURL = @"";
                                       [self.webview reload];
                                   }];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Abbrechen"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    [alertController addAction:searchAction];
    [alertController addAction:goAction];
    NSURLRequest *request = [_webview request];
    if (request != nil) {
        if (![request.URL.absoluteString  isEqual: @""]) {
            [alertController addAction:reloadAction];
            [alertController addAction:cancelAction];
        }
    }
    [self presentViewController:alertController animated:YES completion:nil];
    if (request == nil) {
        UITextField *loginTextField = alertController.textFields[0];
        [loginTextField becomeFirstResponder];
    }
    else if ([request.URL.absoluteString  isEqual: @""]) {
        UITextField *loginTextField = alertController.textFields[0];
        [loginTextField becomeFirstResponder];
    }
    
}

- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    requestURL = request.URL.absoluteString;
    return YES;
}

- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    [loadingSpinner stopAnimating];
    if (![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"999"] && ![[NSString stringWithFormat:@"%lid", (long)error.code] containsString:@"204"]) {
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"Webseite kann nicht geladen werden"
                                              message:[error localizedDescription]
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *searchAction = [UIAlertAction
                                       actionWithTitle:@"Diese Webseite googlen"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           if (requestURL != nil) {
                                               if ([requestURL length] > 1) {
                                                   NSString *lastChar = [requestURL substringFromIndex: [requestURL length] - 1];
                                                   if ([lastChar isEqualToString:@"/"]) {
                                                       NSString *newString = [requestURL substringToIndex:[requestURL length]-1];
                                                       requestURL = newString;
                                                   }
                                               }
                                               requestURL = [requestURL stringByReplacingOccurrencesOfString:@"http://" withString:@""];
                                               requestURL = [requestURL stringByReplacingOccurrencesOfString:@"https://" withString:@""];
                                               requestURL = [requestURL stringByReplacingOccurrencesOfString:@"www." withString:@""];
                                               [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.de/search?q=%@", requestURL]]]];
                                           }
                                           
                                       }];
        UIAlertAction *reloadAction = [UIAlertAction
                                       actionWithTitle:@"Seite aktualisieren"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           previousURL = @"";
                                           [self.webview reload];
                                       }];
        UIAlertAction *newurlAction = [UIAlertAction
                                       actionWithTitle:@"Adresse oder Suchbegriff eingeben"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action)
                                       {
                                           [self requestURLorSearchInput];
                                       }];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Abbrechen"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action)
                                       {
                                       }];
        if (requestURL != nil) {
            if ([requestURL length] > 1) {
                [alertController addAction:searchAction];
            }
        }
        
        NSURLRequest *request = [_webview request];
        if (request != nil) {
            if (![request.URL.absoluteString  isEqual: @""]) {
                [alertController addAction:reloadAction];
            }
            else {
                [alertController addAction:newurlAction];
            }
        }
        else {
            [alertController addAction:newurlAction];
        }
        
        [alertController addAction:cancelAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

-(void)toggleMode {
    self.cursorMode = !self.cursorMode;
    UIScrollView *scrollView = [self.webview scrollView];
    
    if (self.cursorMode)
    {
        scrollView.scrollEnabled = NO;
        [self.webview setUserInteractionEnabled:NO];
        cursorView.hidden = NO;
    }
    else
    {
        scrollView.scrollEnabled = YES;
        [self.webview setUserInteractionEnabled:YES];
        cursorView.hidden = YES;
    }
}

- (void)showHintsAlert {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Bedienungsanleitung"
                                          message:@"Doppelklick für Wechsel zwischen Maus- und Scroll-Modus.\nKlick für Mausklick im Maus-Modus.\nMENU-Button drücken, um zurück zu navigieren.\nPlay/Pause drücken, um eine Adresse einzugeben.\nDoppelklick auf Play/Pause für mehr Optionen."
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *hideForeverAction = [UIAlertAction
                                        actionWithTitle:@"Nicht nochmal anzeigen"
                                        style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *action)
                                        {
                                            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DontShowHintsOnLaunch"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                        }];
    UIAlertAction *showForeverAction = [UIAlertAction
                                        actionWithTitle:@"Beim nächsten Start zeigen"
                                        style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *action)
                                        {
                                            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DontShowHintsOnLaunch"];
                                            [[NSUserDefaults standardUserDefaults] synchronize];
                                        }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Abbrechen"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DontShowHintsOnLaunch"]) {
        [alertController addAction:showForeverAction];
    }
    else {
        [alertController addAction:hideForeverAction];
    }
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)alertTextFieldShouldReturn:(UITextField *)sender {
    /*
     _inputViewVisible = NO;
     UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
     if (alertController)
     {
     [alertController dismissViewControllerAnimated:true completion:nil];
     if ([temporaryURL containsString:@" "] || ![temporaryURL containsString:@"."]) {
     temporaryURL = [temporaryURL stringByReplacingOccurrencesOfString:@" " withString:@"+"];
     temporaryURL = [temporaryURL stringByReplacingOccurrencesOfString:@"." withString:@"+"];
     temporaryURL = [temporaryURL stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
     temporaryURL = [temporaryURL stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
     temporaryURL = [temporaryURL stringByReplacingOccurrencesOfString:@"++" withString:@"+"];
     temporaryURL = [temporaryURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
     if (temporaryURL != nil) {
     [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/search?q=%@", temporaryURL]]]];
     }
     else {
     [self requestURLorSearchInput];
     }
     temporaryURL = nil;
     }
     else {
     if (temporaryURL != nil) {
     if ([temporaryURL containsString:@"http://"] || [temporaryURL containsString:@"https://"]) {
     [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@", temporaryURL]]]];
     temporaryURL = nil;
     }
     else {
     [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://%@", temporaryURL]]]];
     temporaryURL = nil;
     }
     }
     else {
     [self requestURLorSearchInput];
     }
     }
     
     }
     */
}

-(void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu)
    {
        UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
        if (alertController)
        {
            [self.presentedViewController dismissViewControllerAnimated:true completion:nil];
        }
        else if ([self.webview canGoBack]) {
            [self.webview goBack];
        }
        else {
            [self requestURLorSearchInput];
        }
        
    }
    else if (presses.anyObject.type == UIPressTypeUpArrow)
    {
        // Zoom testing (needs work) (requires old remote for up arrow)
        //UIScrollView * sv = self.webview.scrollView;
        //[sv setZoomScale:30];
    }
    else if (presses.anyObject.type == UIPressTypeDownArrow)
    {
    }
    else if (presses.anyObject.type == UIPressTypeSelect)
    {
        if(!self.cursorMode)
        {
            //[self toggleMode];
        }
        else
        {
            /* Gross. */
            CGPoint point = [self.webview convertPoint:cursorView.frame.origin toView:nil];
            
            [self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).click()", (int)point.x, (int)point.y]];
            // Make the UIWebView method call
            NSString *fieldType = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).type;", (int)point.x, (int)point.y]];
            /*
             if (fieldType == nil) {
             NSString *contentEditible = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).getAttribute('contenteditable');", (int)point.x, (int)point.y]];
             NSLog(contentEditible);
             if ([contentEditible isEqualToString:@"true"]) {
             fieldType = @"text";
             }
             }
             else if ([[fieldType stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString: @""]) {
             NSString *contentEditible = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).getAttribute('contenteditable');", (int)point.x, (int)point.y]];
             NSLog(contentEditible);
             if ([contentEditible isEqualToString:@"true"]) {
             fieldType = @"text";
             }
             }
             NSLog(fieldType);
             */
            fieldType = fieldType.lowercaseString;
            if ([fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] || [fieldType isEqualToString:@"datetime-local"] || [fieldType isEqualToString:@"email"] || [fieldType isEqualToString:@"month"] || [fieldType isEqualToString:@"number"] || [fieldType isEqualToString:@"password"] || [fieldType isEqualToString:@"tel"] || [fieldType isEqualToString:@"text"] || [fieldType isEqualToString:@"time"] || [fieldType isEqualToString:@"url"] || [fieldType isEqualToString:@"week"]) {
                NSString *fieldTitle = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).title;", (int)point.x, (int)point.y]];
                if ([fieldTitle isEqualToString:@""]) {
                    fieldTitle = fieldType;
                }
                NSString *placeholder = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).placeholder;", (int)point.x, (int)point.y]];
                if ([placeholder isEqualToString:@""]) {
                    if (![fieldTitle isEqualToString:fieldType]) {
                        placeholder = [NSString stringWithFormat:@"%@", fieldTitle];
                    }
                    else {
                        placeholder = @"Text";
                    }
                }
                NSString *testedFormResponse = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).form.hasAttribute('onsubmit');", (int)point.x, (int)point.y]];
                UIAlertController *alertController = [UIAlertController
                                                      alertControllerWithTitle:@"Text eingeben"
                                                      message: [fieldTitle capitalizedString]
                                                      preferredStyle:UIAlertControllerStyleAlert];
                
                [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField)
                 {
                     if ([fieldType isEqualToString:@"url"]) {
                         textField.keyboardType = UIKeyboardTypeURL;
                     }
                     else if ([fieldType isEqualToString:@"email"]) {
                         textField.keyboardType = UIKeyboardTypeEmailAddress;
                     }
                     else if ([fieldType isEqualToString:@"tel"] || [fieldType isEqualToString:@"number"] || [fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] || [fieldType isEqualToString:@"datetime-local"]) {
                         textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
                     }
                     else {
                         textField.keyboardType = UIKeyboardTypeDefault;
                     }
                     textField.placeholder = [placeholder capitalizedString];
                     if ([fieldType isEqualToString:@"password"]) {
                         textField.secureTextEntry = YES;
                     }
                     textField.text = [_webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).value;", (int)point.x, (int)point.y]];
                     textField.textColor = [UIColor blackColor];
                     textField.backgroundColor = [UIColor whiteColor];
                     [textField setReturnKeyType:UIReturnKeyDone];
                     [textField addTarget:self
                                   action:@selector(alertTextFieldShouldReturn:)
                         forControlEvents:UIControlEventEditingDidEnd];
                     
                 }];
                UIAlertAction *inputAndSubmitAction = [UIAlertAction
                                                       actionWithTitle:@"Absenden"
                                                       style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action)
                                                       {
                                                           UITextField *inputViewTextField = alertController.textFields[0];
                                                           NSString *javaScript = [NSString stringWithFormat:@"var textField = document.elementFromPoint(%i, %i);"
                                                                                   "textField.value = '%@';"
                                                                                   "textField.form.submit();"
                                                                                   //"var ev = document.createEvent('KeyboardEvent');"
                                                                                   //"ev.initKeyEvent('keydown', true, true, window, false, false, false, false, 13, 0);"
                                                                                   //"document.body.dispatchEvent(ev);"
                                                                                   , (int)point.x, (int)point.y, inputViewTextField.text];
                                                           [_webview stringByEvaluatingJavaScriptFromString:javaScript];
                                                       }];
                UIAlertAction *inputAction = [UIAlertAction
                                              actionWithTitle:@"Fertig"
                                              style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action)
                                              {
                                                  UITextField *inputViewTextField = alertController.textFields[0];
                                                  NSString *javaScript = [NSString stringWithFormat:@"var textField = document.elementFromPoint(%i, %i);"
                                                                          "textField.value = '%@';", (int)point.x, (int)point.y, inputViewTextField.text];
                                                  [_webview stringByEvaluatingJavaScriptFromString:javaScript];
                                              }];
                UIAlertAction *cancelAction = [UIAlertAction
                                               actionWithTitle:@"Abbrechen"
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *action)
                                               {
                                               }];
                [alertController addAction:inputAction];
                if (testedFormResponse != nil) {
                    if ([testedFormResponse isEqualToString:@"true"]) {
                        [alertController addAction:inputAndSubmitAction];
                    }
                }
                [alertController addAction:cancelAction];
                [self presentViewController:alertController animated:YES completion:nil];
                UITextField *inputViewTextField = alertController.textFields[0];
                if ([[inputViewTextField.text stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@""]) {
                    [inputViewTextField becomeFirstResponder];
                }
            }
            else {
                //[self.webview stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.elementFromPoint(%i, %i).click()", (int)point.x, (int)point.y]];
            }
            //[self toggleMode];
        }
    }
    else if (presses.anyObject.type == UIPressTypePlayPause)
    {
        UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
        if (alertController)
        {
            [self.presentedViewController dismissViewControllerAnimated:true completion:nil];
        }
        else {
            [self requestURLorSearchInput];
        }
    }
}

- (void)longPress:(UILongPressGestureRecognizer*)gesture {
    if ( gesture.state == UIGestureRecognizerStateBegan) {
        //[self toggleMode];
        /*
         //if ([_webview.scrollView zoomScale] != 1.0) {
         if (![[_webview stringByEvaluatingJavaScriptFromString:@"document. body.style.zoom;"]  isEqual: @"1.0"]) {
         [_webview stringByEvaluatingJavaScriptFromString:@"document. body.style.zoom = 1.0;"];
         }
         else {
         [_webview stringByEvaluatingJavaScriptFromString:@"document. body.style.zoom = 5.0;"];
         }
         */
        
    }
    else if ( gesture.state == UIGestureRecognizerStateEnded) {
        //[self toggleMode];
    }
}

#pragma mark - Cursor Input

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.lastTouchLocation = CGPointMake(-1, -1);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches)
    {
        CGPoint location = [touch locationInView:self.webview];
        
        if(self.lastTouchLocation.x == -1 && self.lastTouchLocation.y == -1)
        {
            // Prevent cursor from recentering
            self.lastTouchLocation = location;
        }
        else
        {
            CGFloat xDiff = (location.x - self.lastTouchLocation.x) / 3.0;
            CGFloat yDiff = (location.y - self.lastTouchLocation.y) / 3.0;
            CGRect rect = cursorView.frame;
            
            if(rect.origin.x + xDiff >= 0 && rect.origin.x + xDiff <= 1920)
                rect.origin.x += xDiff;//location.x - self.startPos.x;//+= xDiff; //location.x;
            
            if(rect.origin.y + yDiff >= 0 && rect.origin.y + yDiff <= 1080)
                rect.origin.y += yDiff;//location.y - self.startPos.y;//+= yDiff; //location.y;
            
            cursorView.frame = rect;
            self.lastTouchLocation = location;
        }
        
        CGPoint point = [self.webview convertPoint:cursorView.frame.origin toView:nil];
        
        // We only use one touch, break the loop
        break;
    }
}

@end
