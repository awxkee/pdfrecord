//
//  PDFHummusService.h
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 06/05/2022.
//

#ifndef PDFHummusService_h
#define PDFHummusService_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PDFRecord : NSObject
-(nonnull id)initEmpty:(nullable NSString*)password readProtection:(bool)readProtection;
-(nonnull id)initEmptyToURL:(nonnull NSURL*)fileURL password:(nullable NSString*)password readProtection:(bool)readProtection;
-(nullable id)initWithPath:(nonnull NSString*)path password:(nullable NSString*)password error:(NSError * _Nullable * _Nullable)error;
-(void)addImagePage:(nonnull NSString*)imagePath mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect;
-(nullable void*)appendRecord:(nonnull NSData*)pdfData password:(nullable NSString*)password error:(NSError * _Nullable * _Nullable)error;
-(void)addJpegPage:(nonnull NSData*)jpegData imageDimensions:(CGSize)imageDimensions mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect;
-(void)addPNGData:(nonnull NSData*)jpegData imageDimensions:(CGSize)imageDimensions mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect;
+(nullable NSData*)recryptPDF:(nonnull NSData*)pdfData oldPassword:(nullable NSString*)oldPassword newPassword:(nullable NSString*)newPassword readProtection:(bool)readProtection error:(NSError * _Nullable * _Nullable)error;
+(NSUInteger)getPagesCount:(nonnull NSData*)pdfData password:(nullable NSString*)password;
+(nullable NSData*)swapPages:(nonnull NSData*)pdfData password:(nullable NSString*)password readProtection:(bool)readProtection from:(NSUInteger)from
                          to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error;
+(nullable NSURL*)addPagesCounter:(nonnull NSURL*)fileURL toURL:(nonnull NSURL*)toURL password:(nullable NSString*)password formatter:(nonnull NSString*)formatter error:(NSError * _Nullable * _Nullable)error;
+(nullable NSData*)addWatermark:(nonnull NSData*)data password:(nullable NSString*)password text:(nonnull NSString*)text color:(nonnull UIColor*)color error:(NSError * _Nullable * _Nullable)error;
+(NSUInteger)getPagesCountForURL:(nonnull NSURL*)pdfURL password:(nullable NSString*)password;
-(nullable void*)appendPagesFrom:(nonnull NSURL*)url password:(nullable NSString*)password from:(NSUInteger)from to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error;
+(nullable NSData*)deletePage:(nonnull NSData*)pdfData password:(nullable NSString*)password readProtection:(bool)readProtection page:(int)page error:(NSError * _Nullable * _Nullable)error;
-(nullable void*)appendPages:(nonnull NSData*)pdfData password:(nullable NSString*)password from:(NSUInteger)from to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error;
+(nullable NSData*)extractPages:(nonnull NSData*)pdfData password:(nullable NSString*)password pages:(nonnull NSArray*)pages error:(NSError * _Nullable * _Nullable)error;
+(nullable NSURL*)addProjectWatermark:(nonnull NSURL*)fileURL toURL:(nonnull NSURL*)toURL password:(nullable NSString*)password text:(nonnull NSString*)text link:(nonnull NSString*)link appIcon:(nonnull NSData*)appIcon error:(NSError * _Nullable * _Nullable)error;
-(nullable void*)finish:(NSError * _Nullable * _Nullable)error;
-(nullable NSData*)dataRepresentation;
@end

#endif /* PDFHummusService_h */
