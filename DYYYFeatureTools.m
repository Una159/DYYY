#import "DYYYFeatureTools.h"
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DYYYVoicePackViewController () <UIDocumentPickerDelegate, AVAudioPlayerDelegate>
@property(nonatomic, copy) NSArray<NSURL *> *audioURLs;
@property(nonatomic, strong) AVAudioPlayer *player;
@property(nonatomic, strong) UILabel *emptyLabel;
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
    cell.detailTextLabel.text = @"点击播放 · 长按删除";
    cell.imageView.image = [UIImage systemImageNamed:@"waveform"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSURL *url = self.audioURLs[indexPath.row];
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
