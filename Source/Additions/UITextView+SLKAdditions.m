//
//   Copyright 2014 Slack Technologies, Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import "UITextView+SLKAdditions.h"

@implementation UITextView (SLKAdditions)

- (NSUInteger)numberOfLines
{
    return abs(self.contentSize.height/self.font.lineHeight);
}

- (void)scrollToCaretPositonAnimated:(BOOL)animated
{
    if (!animated)
    {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.0];
        [UIView setAnimationDelay:0.0];
        [UIView setAnimationCurve:UIViewAnimationCurveLinear];
        
        [self scrollRangeToVisible:self.selectedRange];
        
        [UIView commitAnimations];
    }
    else {
        [self scrollRangeToVisible:self.selectedRange];
    }
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    CGRect rect = [self caretRectForPosition:self.selectedTextRange.end];
    rect.size.height += self.textContainerInset.bottom;
    
    if (!animated)
    {
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:0.0];
        [UIView setAnimationDelay:0.0];
        [UIView setAnimationCurve:UIViewAnimationCurveLinear];
        
        [self scrollRectToVisible:rect animated:animated];
        
        [UIView commitAnimations];
    }
    else {
        [self scrollRectToVisible:rect animated:animated];
    }
}

- (void)insertNewLineBreak
{
    [self insertTextAtCaretRange:@"\n"];
    
    BOOL animated = YES;
    SEL expandingSelector = NSSelectorFromString(@"isExpanding");
    
    if ([self respondsToSelector:expandingSelector]) {
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        BOOL isExpanding = (BOOL)[self performSelector:expandingSelector withObject:nil];
#pragma clang diagnostic pop
        
        // if the text view cannot expand anymore, scrolling to bottom are not animated to fix a UITextView issue scrolling twice.
        animated = !isExpanding;
    }
    
    //Detected break. Should scroll to bottom if needed.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0025 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToBottomAnimated:animated];
    });
}

- (void)insertTextAtCaretRange:(NSString *)text
{
    NSRange range = [self insertText:text inRange:self.selectedRange];
    self.selectedRange = NSMakeRange(range.location, 0);
}

- (NSRange)insertText:(NSString *)text inRange:(NSRange)range
{
    // Skip if the text is empty
    if (text.length == 0) {
        return NSMakeRange(0, 0);
    }
    
    // Append the new string at the caret position
    if (range.length == 0)
    {
        NSString *leftString = [self.text substringToIndex:range.location];
        NSString *rightString = [self.text substringFromIndex: range.location];
        
        self.text = [NSString stringWithFormat:@"%@%@%@", leftString, text, rightString];
        
        range.location += [text length];
        return range;
    }
    // Some text is selected, so we replace it with the new text
    else if (range.length > 0)
    {
        self.text = [self.text stringByReplacingCharactersInRange:range withString:text];
        
        return NSMakeRange(range.location+[self.text rangeOfString:text].length, text.length);
    }
    
    // No text has been inserted, but still return the caret range
    return self.selectedRange;
}

- (NSString *)wordAtCaretRange:(NSRangePointer)range
{
    return [self wordAtRange:self.selectedRange rangeInText:range];
}

- (NSString *)wordAtRange:(NSRange)range rangeInText:(NSRangePointer)rangePointer
{
    NSString *text = self.text;
    NSInteger location = range.location;
    
    if (text.length == 0) {
        *rangePointer = NSMakeRange(0.0, 0.0);
        return nil;
    }
    
    NSString *leftPortion = [text substringToIndex:location];
    NSArray *leftComponents = [leftPortion componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *leftWordPart = [leftComponents lastObject];
    
    NSString *rightPortion = [text substringFromIndex:location];
    NSArray *rightComponents = [rightPortion componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *rightPart = [rightComponents firstObject];
    
    if (location > 0) {
        NSString *characterBeforeCursor = [text substringWithRange:NSMakeRange(location-1, 1)];
        
        if ([characterBeforeCursor isEqualToString:@" "]) {
            // At the start of a word, just use the word behind the cursor for the current word
            *rangePointer = NSMakeRange(location, rightPart.length);
            
            return rightPart;
        }
    }
    
    // In the middle of a word, so combine the part of the word before the cursor, and after the cursor to get the current word
    *rangePointer = NSMakeRange(location-leftWordPart.length, leftWordPart.length+rightPart.length);
    NSString *word = [leftWordPart stringByAppendingString:rightPart];
    
    // If a break is detected, return the last component of the string
    if ([word rangeOfString:@"\n"].location != NSNotFound) {
        *rangePointer = [text rangeOfString:word];
        
        NSLog(@"found a break");
        
        word = [[word componentsSeparatedByString:@"\n"] lastObject];
    }

    return word;
}

- (void)disableQuickTypeBar:(BOOL)disable
{
    self.autocorrectionType = disable ? UITextAutocorrectionTypeNo : UITextAutocorrectionTypeDefault;
    
    if (self.isFirstResponder) {
        [self resignFirstResponder];
        [self becomeFirstResponder];
    }
}

@end
