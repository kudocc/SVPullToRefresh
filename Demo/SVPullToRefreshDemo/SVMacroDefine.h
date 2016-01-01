#import <Foundation/Foundation.h>

#define ScreenHeight         [[UIScreen mainScreen] bounds].size.height
#define ScreenWidth          [[UIScreen mainScreen] bounds].size.width
#define StateBarHeight       20
#define NavigationBarHeight  44
#define TabBarHeight         49
#define MainHeight           (ScreenHeight - StateBarHeight)
#define MainWidth            ScreenWidth

#define ContentFillScreen 0

@interface DWMacroDefine : NSObject

@end
