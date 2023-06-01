//
//  PDFHummusService.m
//  Document Scanner
//
//  Created by Radzivon Bartoshyk on 06/05/2022.
//

#import <Foundation/Foundation.h>
#import "PDFWriter.h"
#import "EStatusCode.h"
#import "PDFPageInput.h"
#import "PDFPage.h"
#import "PDFImageXObject.h"
#import "PageContentContext.h"
#import "PDFFormXObject.h"
#import "JPEGImageParser.h"
#import "PDFModifiedPage.h"
#import "BufferWriteStream.hpp"
#import "PDFUsedFont.h"
#import "PDFDocumentCopyingContext.h"
#import "InfoDictionary.h"
#import "PDFRecord.hpp"
#import "BufferReadStream.hpp"

std::string nsStringToStdC(NSString* str) {
    std::string result;
    if (str) {
        result = std::string([str UTF8String]);
    } else {
        result = std::string();
    }
    return result;
}

NSString * const AppendingPagesError = @"Appending PDF pages was failed";
NSString * const FinishingPDFError = @"Finishing PDF was failed";
NSString * const StartingPDFError = @"Starting PDF was failed";
NSString * const LoadingFontError = @"Loading font was failed";
NSString * const InvalidPageError = @"Invalid page was provided";

@implementation PDFRecord {
    PDFWriter *writer;
    BufferWriterStream* stream;
}

-(nullable NSData*)dataRepresentation {
    if (stream) {
        unsigned long size;
        auto bytes = stream->getBuffer(&size);
        auto newData = [[NSMutableData alloc] initWithBytes:bytes length:size];
        return newData;
    }
    return NULL;
}

-(void)addImagePage:(nonnull NSString*)imagePath mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect {
    auto page = new PDFPage();
    page->SetMediaBox(PDFRectangle(mediaBox.origin.x, mediaBox.origin.y, mediaBox.size.width, mediaBox.size.height));
    PageContentContext* contentContext = writer->StartPageContentContext(page);
    AbstractContentContext::ImageOptions opt3;
    
    opt3.transformationMethod = AbstractContentContext::eFit;
    opt3.boundingBoxHeight = imageRect.size.height;
    opt3.boundingBoxWidth = imageRect.size.width;
    opt3.fitProportional = true;
    contentContext->DrawImage(imageRect.origin.x, imageRect.origin.y, imagePath.UTF8String, opt3);
    
    writer->EndPageContentContext(contentContext);
    writer->WritePageAndRelease(page);
}

-(void)addJpegPage:(nonnull NSData*)jpegData imageDimensions:(CGSize)imageDimensions mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect {
    JPEGImageInformation imageInfo;
    ObjectIDType formXObjectID =
    writer->GetObjectsContext().GetInDirectObjectsRegistry().AllocateNewObjectID();
    auto stream = new BufferReadStream((char*)[jpegData bytes], [jpegData length]);
    auto xObject = writer->CreateImageXObjectFromJPGStream(stream, formXObjectID);
    if (!xObject) {
        delete stream;
        return;
    }
    
    delete stream;
    
    [self addXObjectImage:formXObjectID imageDimensions:imageDimensions mediaBox:mediaBox imageRect:imageRect];
    
    delete xObject;
}

-(void)addPNGData:(nonnull NSData*)jpegData imageDimensions:(CGSize)imageDimensions mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect {
    ObjectIDType formXObjectID =
    writer->GetObjectsContext().GetInDirectObjectsRegistry().AllocateNewObjectID();
    auto stream = new BufferReadStream((char*)jpegData.bytes, jpegData.length);
    auto xObject = writer->CreateFormXObjectFromPNGStream(stream, formXObjectID);
    if (!xObject) {
        delete stream;
        return;
    }
    
    delete stream;
    
    [self addXObjectImage:formXObjectID imageDimensions:imageDimensions mediaBox:mediaBox imageRect:imageRect];
    
    delete xObject;
}

-(void)addXObjectImage:(ObjectIDType)formXObjectID imageDimensions:(CGSize)imageDimensions mediaBox:(CGRect)mediaBox imageRect:(CGRect)imageRect {
    auto page = new PDFPage();
    page->SetMediaBox(PDFRectangle(mediaBox.origin.x, mediaBox.origin.y, mediaBox.size.width, mediaBox.size.height));
    double transformation[6] = {imageDimensions.width,0,0,imageDimensions.height,0,0};
    
    double scaleX = 1;
    double scaleY = 1;
    
    if(imageDimensions.width > imageRect.size.width || imageDimensions.height > imageRect.size.height) // overflow
    {
        scaleX = imageDimensions.width > imageRect.size.width ? imageRect.size.width / imageDimensions.width : 1;
        scaleY = imageDimensions.height > imageRect.size.height ? imageRect.size.height / imageDimensions.height : 1;
    }
    
    scaleX = std::min(scaleX,scaleY);
    scaleY = scaleX;
    
    transformation[0] *= scaleX;
    transformation[3] *= scaleY;
    
    transformation[4] += imageRect.origin.x;
    transformation[5] += imageRect.origin.y;
    
    PageContentContext* contentContext = writer->StartPageContentContext(page);
    contentContext->q();
    contentContext->cm(transformation[0],transformation[1],transformation[2],transformation[3],transformation[4],transformation[5]);
    auto pageImageName = page->GetResourcesDictionary().AddImageXObjectMapping(formXObjectID);
    contentContext->Do(pageImageName);
    contentContext->Q();
    
    writer->EndPageContentContext(contentContext);
    writer->WritePageAndRelease(page);
}

+(nullable NSData*)recryptPDF:(nonnull NSData*)pdfData oldPassword:(nullable NSString*)oldPassword newPassword:(nullable NSString*)newPassword readProtection:(bool)readProtection error:(NSError * _Nullable * _Nullable)error {
    auto readStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    auto writeSteam = BufferWriterStream();
    std::string oldPasswordStd = nsStringToStdC(oldPassword);
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (newPassword) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(newPassword), true, readProtection ? nsStringToStdC(newPassword) : NULL);
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (PDFWriter::RecryptPDF(&readStream, oldPasswordStd, &writeSteam, LogConfiguration::DefaultLogConfiguration(), settings, ePDFVersion17) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Recrypt PDF was failed" }];
        return nil;
    }
    unsigned long bufferSize;
    auto buffer = writeSteam.getBuffer(&bufferSize);
    return [[NSMutableData alloc] initWithBytes:buffer length:bufferSize];
}

-(nullable void*)appendRecord:(nonnull NSData*)pdfData password:(nullable NSString*)password error:(NSError * _Nullable * _Nullable)error {
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto readStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    auto result = writer->AppendPDFPagesFromPDF(&readStream, PDFPageRange(), ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    return (__bridge void*)self;
}

+(nullable NSData*)extractPages:(nonnull NSData*)pdfData password:(nullable NSString*)password pages:(nonnull NSArray*)pages error:(NSError * _Nullable * _Nullable)error {
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto inputStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    auto writer = PDFWriter();
    auto outputStream = BufferWriterStream();
    if (writer.StartPDFForStream(&outputStream, ePDFVersion17, LogConfiguration::DefaultLogConfiguration()) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    auto range = PDFPageRange();
    range.mType = PDFPageRange::eRangeTypeSpecific;
    ULongAndULongList ranges = ULongAndULongList();
    for (int i = 0; i < pages.count; i++) {
        auto number = (NSNumber*)[pages objectAtIndex:i];
        auto numberInt = [number intValue];
        ranges.push_back(ULongAndULong(numberInt, numberInt));
    }
    range.mSpecificRanges = ranges;
    writer.AppendPDFPagesFromPDF(&inputStream, range, ObjectIDTypeList(), options);
    [self insertMetadata:&writer];
    if (writer.EndPDFForStream() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    unsigned long bufferSize;
    char* buffer = outputStream.getBuffer(&bufferSize);
    
    auto results = [[NSMutableData alloc] initWithBytes:buffer length:bufferSize];
    
    return results;
}

+(void)insertMetadata:(nonnull PDFWriter*)writer {
    InfoDictionary& infoDictionary = writer->GetDocumentContext().GetTrailerInformation().GetInfo();
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle]infoDictionary];
    
    NSString *version = bundleInfoDictionary[@"CFBundleShortVersionString"];
    NSString *build = bundleInfoDictionary[(NSString*)kCFBundleVersionKey];
    auto creationTool = [NSString stringWithFormat:@"xPDF Version: %@.%@", version, build];
    infoDictionary.Creator = PDFTextString(nsStringToStdC(creationTool));
    infoDictionary.Producer = PDFTextString(nsStringToStdC(creationTool));
    auto now = PDFDate();
    now.SetToCurrentTime();
    infoDictionary.ModDate = now;
    if (infoDictionary.CreationDate.Year == -1) {
        infoDictionary.CreationDate = now;
    }
}

+(NSUInteger)getPagesCount:(nonnull NSData*)pdfData password:(nullable NSString*)password {
    auto parser = PDFParser();
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto inputStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    if (parser.StartPDFParsing(&inputStream, options) != PDFHummus::eSuccess) {
        return -1;
    }
    auto numberOfPages = parser.GetPagesCount();
    return numberOfPages;
}

+(NSUInteger)getPagesCountForURL:(nonnull NSURL*)pdfURL password:(nullable NSString*)password {
    auto parser = PDFParser();
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto file = InputFile();
    if (file.OpenFile(nsStringToStdC([pdfURL path])) != PDFHummus::eSuccess) {
        return -1;
    }
    if (parser.StartPDFParsing(file.GetInputStream(), options) != PDFHummus::eSuccess) {
        return -1;
    }
    auto numberOfPages = parser.GetPagesCount();
    return numberOfPages;
}

+(ULongAndULongList)makeFinishedVector:(std::vector<int>)startVector {
    ULongAndULongList ranges = ULongAndULongList();
    if (startVector.size() == 0) {
        return ranges;
    }
    for (int i = 0; i < startVector.size(); i++) {
        ranges.push_back(ULongAndULong(startVector[i], startVector[i]));
    }
    return ranges;
}

+(nullable NSData*)swapPages:(nonnull NSData*)pdfData password:(nullable NSString*)password readProtection:(bool)readProtection from:(NSUInteger)from
                          to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error {
    auto numberOfPages = [PDFRecord getPagesCount:pdfData password:password];
    if (numberOfPages <= 0) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    
    auto outputStream = BufferWriterStream();
    auto writer = PDFWriter();
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), readProtection, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer.StartPDFForStream(&outputStream, ePDFVersion17, LogConfiguration::DefaultLogConfiguration(), settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    
    auto readStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    
    auto initialVector = std::vector<int>();
    for (int i = 0; i < numberOfPages; i++) {
        if (i == from) {
            initialVector.push_back((int)to);
        } else if (i == to) {
            initialVector.push_back((int)from);
        } else {
            initialVector.push_back(i);
        }
    }
    
    readStream.Reset();
    auto range = PDFPageRange();
    range.mType = PDFPageRange::eRangeTypeSpecific;
    ULongAndULongList ranges = [PDFRecord makeFinishedVector:initialVector];
    range.mSpecificRanges = ranges;
    auto result = writer.AppendPDFPagesFromPDF(&readStream, range, ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    
    [PDFRecord insertMetadata:&writer];
    if (writer.EndPDFForStream() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    unsigned long bufferSize;
    auto buffer = outputStream.getBuffer(&bufferSize);
    auto returningData = [[NSData alloc] initWithBytes:buffer length:bufferSize];
    return returningData;
}

+(nullable NSData*)addWatermark:(nonnull NSData*)data password:(nullable NSString*)password text:(nonnull NSString*)text color:(nonnull UIColor*)color error:(NSError * _Nullable * _Nullable)error {
    auto writer = PDFWriter();
    auto readStream = BufferReadStream((char*)data.bytes, data.length);
    auto writableStream = BufferWriterStream();
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), password != nil, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer.ModifyPDFForStream(&readStream, &writableStream, false, ePDFVersion17, LogConfiguration::DefaultLogConfiguration(),
                                  settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Modyfing PDF was failed" }];
        return nil;
    }
    
    auto parser = PDFParser();
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    
    auto inputParserStream = BufferReadStream((char*)data.bytes, data.length);
    if (parser.StartPDFParsing(&inputParserStream, options) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    
    auto numberOfPages = parser.GetPagesCount();
    auto fontURL = [[NSBundle mainBundle] URLForResource:@"tahoma_regular" withExtension:@"ttf"];
    if (!fontURL) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    auto font = writer.GetFontForFile(nsStringToStdC([fontURL path]));
    if (!font) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    int rgbColor = ((int)(red * 255) << 16) + ((int)(green * 255) << 8) + (int)(blue * 255);
    
    for (int i = 0; i < numberOfPages; i++) {
        auto formatted = nsStringToStdC(text);
        auto textDimensions = font->CalculateTextDimensions(formatted, 16);
        auto modifiedPage = PDFModifiedPage(&writer, i);
        PDFPageInput pageInput(&parser, parser.ParsePage(i));
        auto mediaBox = pageInput.GetMediaBox();
        AbstractContentContext* contentContext = modifiedPage.StartContentContext();
        AbstractContentContext::TextOptions opt(font, 16, AbstractContentContext::eRGB, rgbColor);
        auto textY = 8.0;
        
        auto pageWidth = ABS((double)(mediaBox.UpperRightX - mediaBox.LowerLeftX));
        auto pageHeight = ABS((double)(mediaBox.UpperRightY - mediaBox.LowerLeftY));
        
        auto rotationTransform = CGAffineTransformRotate(CGAffineTransformTranslate(CGAffineTransformIdentity, pageWidth, 0),
                                                         45*M_PI/180);
        
        contentContext->q();
        contentContext->cm(rotationTransform.a, rotationTransform.b, rotationTransform.c, rotationTransform.d, rotationTransform.tx, rotationTransform.ty);
        
        auto stepX = pageWidth / 6.0;
        auto textCounts = 7;
        auto totalTextWidth = (stepX + textDimensions.width) * textCounts;
        auto startX = 0;
        // if totalTextWidth < pageWidth then grows spaces to fill the page;
        if (totalTextWidth < pageWidth) {
            stepX = (pageWidth - textDimensions.width * textCounts) / textCounts;
            startX = stepX / 2;
        } else {
            startX = (pageWidth - totalTextWidth) / 2;
        }
        
        auto linesCount = 8;
        auto stepY = pageHeight / (double)linesCount;
        textY -= stepY * 2;
        for (int y = 0; y < linesCount + 8; y++) {
            auto currentStartX = startX;
            for (int cnt = 0; cnt < textCounts; cnt++) {
                contentContext->WriteText(currentStartX, textY, nsStringToStdC(text), opt);
                currentStartX += stepX + textDimensions.width;
            }
            textY += stepY;
        }
        
        contentContext->Q();
        
        if (modifiedPage.EndContentContext() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing The Context Signalled Error" }];
            return nil;
        }
        if (modifiedPage.WritePage() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing the page finished with error" }];
            return nil;
        }
    }
    [self insertMetadata:&writer];
    if (writer.EndPDFForStream() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    
    unsigned long bufSize;
    auto buffer = writableStream.getBuffer(&bufSize);
    
    auto returningData = [[NSData alloc] initWithBytes:buffer length:bufSize];
    return returningData;
}

+(nullable NSURL*)addPagesCounter:(nonnull NSURL*)fileURL toURL:(nonnull NSURL*)toURL password:(nullable NSString*)password formatter:(nonnull NSString*)formatter error:(NSError * _Nullable * _Nullable)error {
    auto writer = PDFWriter();
    auto inPath = nsStringToStdC([fileURL path]);
    auto outPath = nsStringToStdC([toURL path]);
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), password != nil, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer.ModifyPDF(inPath, ePDFVersion17, outPath, LogConfiguration::DefaultLogConfiguration(),
                         settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Modyfing PDF was failed" }];
        return nil;
    }
    
    auto parser = PDFParser();
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    
    auto inputFile = InputFile();
    if (inputFile.OpenFile(inPath) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    if (parser.StartPDFParsing(inputFile.GetInputStream(), options) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    
    auto numberOfPages = parser.GetPagesCount();
    auto fontURL = [[NSBundle mainBundle] URLForResource:@"tahoma_regular" withExtension:@"ttf"];
    if (!fontURL) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    auto font = writer.GetFontForFile(nsStringToStdC([fontURL path]));
    if (!font) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    
    for (int i = 0; i < numberOfPages; i++) {
        auto formatted = [NSString stringWithFormat:formatter,i + 1, numberOfPages];
        auto textDimensions = font->CalculateTextDimensions(nsStringToStdC(formatted), 10);
        auto modifiedPage = PDFModifiedPage(&writer, i);
        PDFPageInput pageInput(&parser, parser.ParsePage(i));
        auto mediaBox = pageInput.GetMediaBox();
        AbstractContentContext* contentContext = modifiedPage.StartContentContext();
        if (!contentContext) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Page context allocation was failed. Return fail from enumeration" }];
            return nil;
        }
        AbstractContentContext::TextOptions opt(font, 10, AbstractContentContext::eGray, 0);
        auto textX = (mediaBox.UpperRightX - textDimensions.width) / 2;
        auto textY = 8.0;
        contentContext->q();
        contentContext->WriteText(textX, textY, nsStringToStdC(formatted), opt);
        contentContext->Q();
        
        if (modifiedPage.EndContentContext() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing The Context Signalled Error" }];
            return nil;
        }
        if (modifiedPage.WritePage() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing the page finished with error" }];
            return nil;
        }
    }
    [self insertMetadata:&writer];
    if (writer.EndPDF() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    
    return toURL;
}

+(nullable NSURL*)addProjectWatermark:(nonnull NSURL*)fileURL toURL:(nonnull NSURL*)toURL password:(nullable NSString*)password text:(nonnull NSString*)text link:(nonnull NSString*)link appIcon:(nonnull NSData*)appIcon error:(NSError * _Nullable * _Nullable)error {
    auto writer = PDFWriter();
    auto inPath = nsStringToStdC([fileURL path]);
    auto outPath = nsStringToStdC([toURL path]);
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), password != nil, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer.ModifyPDF(inPath, ePDFVersion17, outPath, LogConfiguration::DefaultLogConfiguration(),
                         settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Modyfing PDF was failed" }];
        return nil;
    }
    
    auto parser = PDFParser();
    
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto inputFile = InputFile();
    if (inputFile.OpenFile(inPath) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Opening file was failed" }];
        return nil;
    }
    if (parser.StartPDFParsing(inputFile.GetInputStream(), options) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    
    auto numberOfPages = parser.GetPagesCount();
    auto fontURL = [[NSBundle mainBundle] URLForResource:@"tahoma_regular" withExtension:@"ttf"];
    if (!fontURL) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    auto font = writer.GetFontForFile(nsStringToStdC([fontURL path]));
    if (!font) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: LoadingFontError }];
        return nil;
    }
    
    ObjectIDType formXObjectID = writer.GetObjectsContext().GetInDirectObjectsRegistry().AllocateNewObjectID();
    auto stream = BufferReadStream((char*)[appIcon bytes], [appIcon length]);
    auto xObject = writer.CreateFormXObjectFromPNGStream(&stream, formXObjectID);
    if (!xObject) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Creating PNG Icon was failed" }];
        return nil;
    }
    
    auto textDimensions = font->CalculateTextDimensions(nsStringToStdC(text), 14);
    for (int i = 0; i < numberOfPages; i++) {
        auto modifiedPage = PDFModifiedPage(&writer, i);
        PDFPageInput pageInput(&parser, parser.ParsePage(i));
        auto mediaBox = pageInput.GetMediaBox();
        AbstractContentContext* contentContext = modifiedPage.StartContentContext();
        AbstractContentContext::TextOptions opt(font, 14, AbstractContentContext::eRGB, 0x0645AD);
        auto textX = mediaBox.UpperRightX - textDimensions.width - 16.0;
        auto textY = 8.0;
        contentContext->q();
        contentContext->WriteText(textX, textY, nsStringToStdC(text), opt);
        contentContext->Q();
        auto appIconSize = 14;
        auto rectangle = PDFRectangle(textX - 8 - appIconSize, textY - 6, textX + textDimensions.width, textY - 6 + textDimensions.height + 12);
        auto imageDimensions = CGSizeMake(256, 256);
        auto imageRect = CGRectMake(textX - 8 - appIconSize, textY - (appIconSize - textDimensions.height) / 2, appIconSize, appIconSize);
        double transformation[6] = {1,0,0,1,0,0};
        
        double scaleX = 1;
        double scaleY = 1;
        
        if(imageDimensions.width > imageRect.size.width || imageDimensions.height > imageRect.size.height) // overflow
        {
            scaleX = imageDimensions.width > imageRect.size.width ? imageRect.size.width / imageDimensions.width : 1;
            scaleY = imageDimensions.height > imageRect.size.height ? imageRect.size.height / imageDimensions.height : 1;
        }
        
        scaleX = std::min(scaleX,scaleY);
        scaleY = scaleX;
        
        transformation[0] *= scaleX;
        transformation[3] *= scaleY;
        
        transformation[4] += imageRect.origin.x;
        transformation[5] += imageRect.origin.y;
        
        contentContext->q();
        contentContext->cm(transformation[0],transformation[1],transformation[2],transformation[3],transformation[4],transformation[5]);
        auto pageImageName = modifiedPage.GetCurrentResourcesDictionary()->AddFormXObjectMapping(formXObjectID);
        contentContext->Do(pageImageName);
        contentContext->Q();
        
        if (modifiedPage.EndContentContext() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing The Context Signalled Error" }];
            return nil;
        }
        if (writer.AttachURLLinktoCurrentPage(nsStringToStdC(link), rectangle) != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Attaching link to PDF was failed Error" }];
            return nil;
        }
        if (modifiedPage.WritePage() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Writing the page finished with error" }];
            return nil;
        }
    }
    [self insertMetadata:&writer];
    if (writer.EndPDF() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    
    return toURL;
}

-(nullable void*)appendPages:(nonnull NSData*)pdfData password:(nullable NSString*)password from:(NSUInteger)from to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error {
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto inputStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    auto range = PDFPageRange();
    range.mType = PDFPageRange::eRangeTypeSpecific;
    ULongAndULongList ranges = ULongAndULongList();
    ranges.push_back(ULongAndULong(from, to));
    range.mSpecificRanges = ranges;
    auto result = writer->AppendPDFPagesFromPDF(&inputStream, range, ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    
    return (__bridge void*)self;
}

-(nullable void*)appendPagesFrom:(nonnull NSURL*)url password:(nullable NSString*)password from:(NSUInteger)from to:(NSUInteger)to error:(NSError * _Nullable * _Nullable)error {
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto inputFile = InputFile();
    inputFile.OpenFile(nsStringToStdC([url path]));
    auto range = PDFPageRange();
    range.mType = PDFPageRange::eRangeTypeSpecific;
    ULongAndULongList ranges = ULongAndULongList();
    ranges.push_back(ULongAndULong(from, to));
    range.mSpecificRanges = ranges;
    auto result = writer->AppendPDFPagesFromPDF(inputFile.GetInputStream(), range, ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    
    return (__bridge void*)self;
}

+(nullable NSData*)deletePage:(nonnull NSData*)pdfData password:(nullable NSString*)password readProtection:(bool)readProtection page:(int)page error:(NSError * _Nullable * _Nullable)error {
    if (page < 0) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: InvalidPageError }];
        return nil;
    }
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    auto parser = PDFParser();
    auto inputStream = BufferReadStream((char*)pdfData.bytes, pdfData.length);
    if (parser.StartPDFParsing(&inputStream, options) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    auto numberOfPages = parser.GetPagesCount();
    if (numberOfPages < page) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: InvalidPageError }];
        return nil;
    }
    inputStream.Reset();
    
    auto outputStream = BufferWriterStream();
    auto writer = PDFWriter();
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), readProtection, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer.StartPDFForStream(&outputStream, ePDFVersion17, LogConfiguration::DefaultLogConfiguration(), settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    auto range = PDFPageRange();
    range.mType = PDFPageRange::eRangeTypeSpecific;
    ULongAndULongList ranges = ULongAndULongList();
    for (int i = 0; i < numberOfPages; i++) {
        if (i != page) {
            ranges.push_back(ULongAndULong(i, i));
        }
    }
    range.mSpecificRanges = ranges;
    auto result = writer.AppendPDFPagesFromPDF(&inputStream, range, ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    [self insertMetadata:&writer];
    if (writer.EndPDFForStream() != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
        return nil;
    }
    unsigned long bufferSize;
    char* buffer = outputStream.getBuffer(&bufferSize);
    
    auto results = [[NSMutableData alloc] initWithBytes:buffer length:bufferSize];
    
    return results;
}

-(nullable id)initWithPath:(nonnull NSString*)path password:(nullable NSString*)password error:(NSError * _Nullable * _Nullable)error {
    auto options = PDFParsingOptions::DefaultPDFParsingOptions();
    if (password) {
        options.Password = nsStringToStdC(password);
    }
    self->stream = new BufferWriterStream;
    self->writer = new PDFWriter;
    EncryptionOptions encryptionOptions = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        encryptionOptions = EncryptionOptions(nsStringToStdC(password), true, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, encryptionOptions);
    if (writer->StartPDFForStream(stream, ePDFVersion17, LogConfiguration::DefaultLogConfiguration(), settings) != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: StartingPDFError }];
        return nil;
    }
    auto result = writer->AppendPDFPagesFromPDF(nsStringToStdC(path), PDFPageRange(), ObjectIDTypeList(), options);
    if (result.first != PDFHummus::eSuccess) {
        *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: AppendingPagesError }];
        return nil;
    }
    return self;
}

-(nonnull id)initEmptyToURL:(nonnull NSURL*)fileURL password:(nullable NSString*)password readProtection:(bool)readProtection {
    self->writer = new PDFWriter;
    EncryptionOptions options = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        options = EncryptionOptions(nsStringToStdC(password), readProtection, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, options);
    writer->StartPDF(nsStringToStdC([fileURL path]), ePDFVersion17,
                     LogConfiguration::DefaultLogConfiguration(), settings);
    return self;
}

-(nonnull id)initEmpty:(nullable NSString*)password readProtection:(bool)readProtection {
    self->stream = new BufferWriterStream;
    self->writer = new PDFWriter;
    EncryptionOptions options = EncryptionOptions::DefaultEncryptionOptions();
    if (password) {
        options = EncryptionOptions(nsStringToStdC(password), readProtection, nsStringToStdC(password));
    }
    auto settings = PDFCreationSettings(true, true, options);
    writer->StartPDFForStream(stream, ePDFVersion17, LogConfiguration::DefaultLogConfiguration(), settings);
    return self;
}

-(nullable void*)finish:(NSError * _Nullable * _Nullable)error {
    [PDFRecord insertMetadata:writer];
    if (stream) {
        if (writer->EndPDFForStream() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
            return nil;
        }
    } else {
        if (writer->EndPDF() != PDFHummus::eSuccess) {
            *error = [[NSError alloc] initWithDomain:@"PDFRecord" code:500 userInfo:@{ NSLocalizedDescriptionKey: FinishingPDFError }];
            return nil;
        }
    }
    return (__bridge void*)self;
}

-(void)dealloc {
    if (writer != nil) {
        delete writer;
    }
    if (stream != nil) {
        delete stream;
    }
}

@end
