#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, CBAutoScrollDirection) {
    CBAutoScrollDirectionRight,
    CBAutoScrollDirectionLeft
};

@interface CBAutoScrollLabelo2 : UIView <UIScrollViewDelegate>
    @property (nonatomic) CBAutoScrollDirection scrollDirection;
    @property (nonatomic) float scrollSpeed;
    @property (nonatomic) NSTimeInterval pauseInterval;
    @property (nonatomic) NSInteger labelSpacing; 
    @property (nonatomic) UIViewAnimationOptions animationOptions;
    @property (nonatomic, copy, nullable) NSAttributedString *attributedText;
    @property (nonatomic, strong, nonnull) UIColor *textColor;
    @property (nonatomic) NSTextAlignment textAlignment;
    @property (nonatomic, strong, nullable) UIColor *shadowColor;
    @property (nonatomic) CGSize shadowOffset;
    - (void)refreshLabels;
    - (void)setText:(nullable NSString *)text refreshLabels:(BOOL)refresh;
    - (void)setAttributedText:(nullable NSAttributedString *)theText refreshLabels:(BOOL)refresh;
    - (void)scrollLabelIfNeeded;
    - (void)observeApplicationNotifications;
@end