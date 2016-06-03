/* FastAddressBook.h
 *
 * Copyright (C) 2011  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#import "FastAddressBook.h"
#import "QwayManager.h"

@implementation FastAddressBook

static void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context);


+ (BOOL)isAuthorized {
    return !ABAddressBookGetAuthorizationStatus || ABAddressBookGetAuthorizationStatus() ==  kABAuthorizationStatusAuthorized;
}

- (FastAddressBook*)init {
    self = [super init];
    if (self!= nil) {
        addressBookMap = [NSMutableDictionary dictionary];
        addressBook    = nil;
        [self reload];
    }
    return self;
}

+ (NSString*)getContactDisplayName:(ABRecordRef)contact {
    NSString *retString = nil;
    if (contact) {
        retString = CFBridgingRelease(ABRecordCopyCompositeName(contact));
    }
    return retString;
}

+ (UIImage*)squareImageCrop:(UIImage*)image
{
	UIImage *ret = nil;

	// This calculates the crop area.

	float originalWidth  = image.size.width;
	float originalHeight = image.size.height;

	float edge = fminf(originalWidth, originalHeight);

	float posX = (originalWidth - edge) / 2.0f;
	float posY = (originalHeight - edge) / 2.0f;


	CGRect cropSquare = CGRectMake(posX, posY,
								   edge, edge);


	CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropSquare);
	ret = [UIImage imageWithCGImage:imageRef
							  scale:image.scale
						orientation:image.imageOrientation];

	CGImageRelease(imageRef);

	return ret;
}

+ (UIImage*)getContactImage:(ABRecordRef)contact thumbnail:(BOOL)thumbnail {
    UIImage* retImage = nil;
    if (contact && ABPersonHasImageData(contact)) {
        NSData* imgData = CFBridgingRelease(ABPersonCopyImageDataWithFormat(contact, thumbnail?
                                                            kABPersonImageFormatThumbnail: kABPersonImageFormatOriginalSize));

        retImage = [UIImage imageWithData:imgData];

		if (retImage != nil && retImage.size.width != retImage.size.height) {
			NSLog(@"Image is not square : cropping it.");
			return [self squareImageCrop:retImage];
		}
    }

    return retImage;
}

- (ABRecordRef)getContact:(NSString*)address {
    @synchronized (addressBookMap){
        return (__bridge ABRecordRef)[addressBookMap objectForKey:address];
    }
}

+ (BOOL)isSipURI:(NSString*)address {
    return [address hasPrefix:@"sip:"] || [address hasPrefix:@"sips:"];
}

+ (NSString*)appendCountryCodeIfPossible:(NSString*)number {
    if (![number hasPrefix:@"+"] && ![number hasPrefix:@"00"]) {
        NSString* lCountryCode = [[QwayManager instance] lpConfigStringForKey:@"countrycode_preference"];
        if (lCountryCode && [lCountryCode length]>0) {
            //append country code
            return [lCountryCode stringByAppendingString:number];
        }
    }
    return number;
}

+ (NSString*)normalizeSipURI:(NSString*)address {
    // replace all whitespaces (non-breakable, utf8 nbsp etc.) by the "classical" whitespace
    address = [[address componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@" "];
    NSString *normalizedSipAddress = nil;
	LinphoneAddress* linphoneAddress = linphone_core_interpret_url([QwayManager getLc], [address UTF8String]);
    if(linphoneAddress != NULL) {
        char *tmp = linphone_address_as_string_uri_only(linphoneAddress);
        if(tmp != NULL) {
            normalizedSipAddress = [NSString stringWithUTF8String:tmp];
            // remove transport, if any
            NSRange pos = [normalizedSipAddress rangeOfString:@";"];
            if (pos.location != NSNotFound) {
                normalizedSipAddress = [normalizedSipAddress substringToIndex:pos.location];
            }
            ms_free(tmp);
        }
        linphone_address_destroy(linphoneAddress);
    }
    return normalizedSipAddress;
}

+ (NSString*)normalizePhoneNumber:(NSString*)address {
    NSMutableString* lNormalizedAddress = [NSMutableString stringWithString:address];
    [lNormalizedAddress replaceOccurrencesOfString:@" "
                                        withString:@""
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@"("
                                        withString:@""
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@")"
                                        withString:@""
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    [lNormalizedAddress replaceOccurrencesOfString:@"-"
                                        withString:@""
                                           options:0
                                             range:NSMakeRange(0, [lNormalizedAddress length])];
    return [FastAddressBook appendCountryCodeIfPossible:lNormalizedAddress];
}

- (void)saveAddressBook {
	if( addressBook != nil ){
		if( !ABAddressBookSave(addressBook, nil) ){
			NSLog(@"Couldn't save Address Book");
		}
	}
}

- (void)reload {
	CFErrorRef error = NULL;

	// create if it doesn't exist
	if( addressBook == nil ){
        if ([FastAddressBook isAuthorized]) {
            //防止闪退
            addressBook = ABAddressBookCreateWithOptions(NULL, &error);
        }else{
            return;
        }
	}

	if(addressBook != nil) {
		__weak FastAddressBook* weakSelf = self;
		ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
			if( !granted ) {
				NSLog(@"Permission for address book acces was denied: %@", [(__bridge NSError*)error description]);
				return;
			}

			ABAddressBookRegisterExternalChangeCallback(addressBook, sync_address_book, (__bridge void *)(weakSelf));
			[weakSelf loadData];

		});
	} else {
		NSLog(@"Create AddressBook failed, reason: %@", [(__bridge NSError*)error localizedDescription]);
	}
}

- (void)loadData {
    ABAddressBookRevert(addressBook);
    @synchronized (addressBookMap) {
        [addressBookMap removeAllObjects];

        CFArrayRef lContacts = ABAddressBookCopyArrayOfAllPeople(addressBook);
		CFIndex count = CFArrayGetCount(lContacts);
		for(CFIndex idx = 0; idx < count; idx++){
			ABRecordRef lPerson = CFArrayGetValueAtIndex(lContacts, idx);
            // Phone
            {
                ABMultiValueRef lMap = ABRecordCopyValue(lPerson, kABPersonPhoneProperty);
                if(lMap) {
                    for (int i=0; i<ABMultiValueGetCount(lMap); i++) {
                        CFStringRef lValue = ABMultiValueCopyValueAtIndex(lMap, i);

						NSString* lNormalizedKey = [FastAddressBook normalizePhoneNumber:(__bridge NSString *)(lValue)];
                        NSString* lNormalizedSipKey = [FastAddressBook normalizeSipURI:lNormalizedKey];
                        if (lNormalizedSipKey != NULL) lNormalizedKey = lNormalizedSipKey;

						[addressBookMap setObject:(__bridge id)(lPerson) forKey:lNormalizedKey];

						CFRelease(lValue);
                    }
                    CFRelease(lMap);
                }
            }

            // SIP
            {
                ABMultiValueRef lMap = ABRecordCopyValue(lPerson, kABPersonInstantMessageProperty);
                if(lMap) {
                    for(int i = 0; i < ABMultiValueGetCount(lMap); ++i) {
                        CFDictionaryRef lDict = ABMultiValueCopyValueAtIndex(lMap, i);
                        BOOL add = false;
                        if(CFDictionaryContainsKey(lDict, kABPersonInstantMessageServiceKey)) {
                            if(CFStringCompare((CFStringRef)[QwayManager instance].contactSipField, CFDictionaryGetValue(lDict, kABPersonInstantMessageServiceKey), kCFCompareCaseInsensitive) == 0) {
                                add = true;
                            }
                        } else {
                            add = true;
                        }
                        if(add) {
                            NSString* lValue = (__bridge NSString*)CFDictionaryGetValue(lDict, kABPersonInstantMessageUsernameKey);
                            NSString* lNormalizedKey = [FastAddressBook normalizeSipURI:lValue];
                            if(lNormalizedKey != NULL) {
                                [addressBookMap setObject:(__bridge id)(lPerson) forKey:lNormalizedKey];
                            } else {
                                [addressBookMap setObject:(__bridge id)(lPerson) forKey:lValue];
                            }
                        }
                        CFRelease(lDict);
                    }
                    CFRelease(lMap);
                }
            }
        }
		CFRelease(lContacts);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kQwayAddressBookUpdate object:self];
}

void sync_address_book (ABAddressBookRef addressBook, CFDictionaryRef info, void *context) {
    FastAddressBook* fastAddressBook = (__bridge FastAddressBook*)context;
    [fastAddressBook loadData];
}

#pragma mark--displayNameForAddress
+ (NSString *)displayNameForAddress:(const LinphoneAddress *)addr
{
    
    NSString* address = nil;
    if(addr != NULL) {
        BOOL useLinphoneAddress = true;
        // contact name
        char* lAddress = linphone_address_as_string_uri_only(addr);
        if(lAddress) {
            if ([FastAddressBook isAuthorized]) {
                NSString *normalizedSipAddress = [FastAddressBook normalizeSipURI:[NSString stringWithUTF8String:lAddress]];
                ABRecordRef contact = [self getContact:normalizedSipAddress];
                if(contact) {
                    address = [FastAddressBook getContactDisplayName:contact];
                    useLinphoneAddress = false;
                }
            }
            
            ms_free(lAddress);
        }
        if(useLinphoneAddress) {
            const char* lDisplayName = linphone_address_get_display_name(addr);
            const char* lUserName = linphone_address_get_username(addr);
            if (lDisplayName)
                address = [NSString stringWithUTF8String:lDisplayName];
            else if(lUserName)
                address = [NSString stringWithUTF8String:lUserName];
        }
    }
    if(address == nil) {
        address = NSLocalizedString(@"Unknown", nil);
    }
    return address;
}


- (void)dealloc {
    ABAddressBookUnregisterExternalChangeCallback(addressBook, sync_address_book, (__bridge void *)(self));
    CFRelease(addressBook);
}

#pragma mark - Tools

+(NSString *)localizedLabel:(NSString *)label {
	if( label != nil ){
		return CFBridgingRelease(ABAddressBookCopyLocalizedLabel((__bridge CFStringRef)(label)));
	}
	return @"";
}


@end
