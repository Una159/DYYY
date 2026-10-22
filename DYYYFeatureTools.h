#import <UIKit/UIKit.h>

@interface DYYYVoicePackViewController : UITableViewController
@end

#ifdef __cplusplus
extern "C" {
#endif

/// Presents the system Files picker and stores the selected GIF in the tweak-accessible Documents/DYYY directory.
void DYYYPresentProgressGIFPicker(UIViewController *presentingViewController, void (^completion)(NSString * _Nullable savedPath));

/// Returns the locally selected voice-pack audio file, if one has been selected.
NSURL * _Nullable DYYYSelectedVoicePackURL(void);

/// Creates an animated UIImage from a GIF file on disk.
UIImage * _Nullable DYYYAnimatedImageFromGIFPath(NSString *path);

#ifdef __cplusplus
}
#endif
