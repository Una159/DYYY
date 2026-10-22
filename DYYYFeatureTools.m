#import "DYYYFeatureTools.h"
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <ImageIO/ImageIO.h>

@interface DYYYVoicePackViewController () <UIDocumentPickerDelegate, AVAudioPlayerDelegate>
@property(nonatomic, copy) NSArray<NSURL *> *audioURLs;
@property(nonatomic, strong) AVAudioPlayer *player;
@property(nonatomic, strong) UILabel *emptyLabel;
@property(nonatomic, copy) NSString *selectedPath;
@end

@implementation DYYYVoicePackViewController
- (NSURL *)voiceDirectory {
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [documents URLByAppendingPathComponent:@"DYYYVoicePacks" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    return directory;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"评论语音包";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(importAudio)];
    self.tableView.rowHeight = 56;
    self.tableView.tableFooterView = [UIView new];
    self.selectedPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSelectedVoicePackPath"];
    [self reloadAudioFiles];
}
- (void)reloadAudioFiles {
    NSArray<NSURL *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[self voiceDirectory] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSSet *extensions = [NSSet setWithArray:@[@"mp3", @"m4a", @"wav", @"caf", @"aiff", @"aac"]];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSURL *url, NSDictionary *bindings) { return [extensions containsObject:url.pathExtension.lowercaseString]; }];
    self.audioURLs = [files filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
}
- (void)importAudio {
    NSMutableArray *types = [NSMutableArray array];
    if (@available(iOS 14.0, *)) {
        for (NSString *extension in @[@"mp3", @"m4a", @"wav", @"aac", @"caf", @"aiff"]) {
            UTType *type = [UTType typeWithFilenameExtension:extension];
            if (type) [types addObject:type];
        }
    }
    UIDocumentPickerViewController *picker;
    if (@available(iOS 14.0, *)) picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    else picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio"] inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        BOOL scoped = [url startAccessingSecurityScopedResource];
        NSURL *destination = [[self voiceDirectory] URLByAppendingPathComponent:url.lastPathComponent];
        NSString *base = destination.lastPathComponent.stringByDeletingPathExtension;
        NSString *ext = destination.pathExtension;
        NSUInteger suffix = 2;
        while ([[NSFileManager defaultManager] fileExistsAtPath:destination.path]) {
            destination = [[self voiceDirectory] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu.%@", base, (unsigned long)suffix++, ext]];
        }
        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:destination error:&error];
        if (scoped) [url stopAccessingSecurityScopedResource];
        if (error) NSLog(@"[DYYY] 导入语音包失败：%@", error);
    }
    [self reloadAudioFiles];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.audioURLs.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuse = @"DYYYVoicePack";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuse];
    NSURL *url = self.audioURLs[indexPath.row];
    cell.textLabel.text = url.lastPathComponent;
    NSString *selected = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSelectedVoicePackPath"];
    cell.detailTextLabel.text = [url.path isEqualToString:selected] ? @"已选为发送语音 · 点击播放 · 左滑删除" : @"点击播放 · 设为发送语音 · 左滑删除";
    cell.accessoryType = [url.path isEqualToString:selected] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.imageView.image = [UIImage systemImageNamed:@"waveform"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSURL *url = self.audioURLs[indexPath.row];
    [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:@"DYYYSelectedVoicePackPath"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (!self.player || error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法播放" message:error.localizedDescription ?: @"不支持的音频格式" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self.player prepareToPlay]; [self.player play];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        if (self.player.isPlaying && [self.player.url isEqual:self.audioURLs[indexPath.row]]) [self.player stop];
        [[NSFileManager defaultManager] removeItemAtURL:self.audioURLs[indexPath.row] error:nil];
        [self reloadAudioFiles];
    }
}
@end


#pragma mark - GIF picker and selected voice-pack bridge

@interface DYYYGIFPickerCoordinator : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, copy) void (^completion)(NSString * _Nullable savedPath);
@end

@implementation DYYYGIFPickerCoordinator
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if (self.completion) self.completion(nil);
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *source = urls.firstObject;
    if (!source) { if (self.completion) self.completion(nil); return; }
    BOOL scoped = [source startAccessingSecurityScopedResource];
    NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
    NSURL *directory = [documents URLByAppendingPathComponent:@"DYYY" isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    [fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error];
    NSURL *destination = [directory URLByAppendingPathComponent:@"DYYYProgressAnimation.gif"];
    if (!error && [fm fileExistsAtPath:destination.path]) [fm removeItemAtURL:destination error:&error];
    if (!error) [fm copyItemAtURL:source toURL:destination error:&error];
    if (scoped) [source stopAccessingSecurityScopedResource];
    NSString *savedPath = error ? nil : destination.path;
    if (savedPath) {
        [[NSUserDefaults standardUserDefaults] setObject:savedPath forKey:@"DYYYProgressAnimationPath"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        NSLog(@"[DYYY] GIF 导入失败: %@", error);
    }
    if (self.completion) self.completion(savedPath);
}
@end

void DYYYPresentProgressGIFPicker(UIViewController *presentingViewController, void (^completion)(NSString * _Nullable savedPath)) {
    if (!presentingViewController) { if (completion) completion(nil); return; }
    UIDocumentPickerViewController *picker = nil;
    if (@available(iOS 14.0, *)) {
        UTType *gifType = [UTType typeWithFilenameExtension:@"gif"];
        if (!gifType) gifType = [UTType typeWithIdentifier:@"public.data"];
        picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:(gifType ? @[gifType] : @[]) asCopy:YES];
    } else {
        picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"com.compuserve.gif"] inMode:UIDocumentPickerModeImport];
    }
    DYYYGIFPickerCoordinator *coordinator = [DYYYGIFPickerCoordinator new];
    coordinator.completion = completion;
    picker.delegate = coordinator;
    objc_setAssociatedObject(picker, @selector(DYYYPresentProgressGIFPicker), coordinator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presentingViewController presentViewController:picker animated:YES completion:nil];
}

NSURL *DYYYSelectedVoicePackURL(void) {
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYSelectedVoicePackPath"];
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return nil;
    return [NSURL fileURLWithPath:path];
}


UIImage *DYYYAnimatedImageFromGIFPath(NSString *path) {
    if (path.length == 0) return nil;
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return nil;
    size_t count = CGImageSourceGetCount(source);
    NSMutableArray<UIImage *> *frames = [NSMutableArray arrayWithCapacity:count];
    NSTimeInterval duration = 0;
    for (size_t i = 0; i < count; i++) {
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, i, NULL);
        if (!cgImage) continue;
        NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, NULL));
        NSDictionary *gif = properties[(NSString *)kCGImagePropertyGIFDictionary];
        NSNumber *delay = gif[(NSString *)kCGImagePropertyGIFUnclampedDelayTime] ?: gif[(NSString *)kCGImagePropertyGIFDelayTime];
        NSTimeInterval frameDuration = delay.doubleValue;
        if (frameDuration < 0.02) frameDuration = 0.1;
        duration += frameDuration;
        [frames addObject:[UIImage imageWithCGImage:cgImage scale:UIScreen.mainScreen.scale orientation:UIImageOrientationUp]];
        CGImageRelease(cgImage);
    }
    CFRelease(source);
    if (frames.count == 0) return nil;
    if (frames.count == 1) return frames.firstObject;
    return [UIImage animatedImageWithImages:frames duration:MAX(duration, 0.1)];
}
