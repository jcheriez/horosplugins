//
//  LayoutView.m
//  PrintingLayout
//
//  Created by Benoit Deville on 31.08.12.
//
//

#import "PLLayoutView.h"
#import "PLThumbnailView.h"
//#import <OsiriXAPI/BrowserController.h>
#import <OsiriXAPI/DICOMExport.h>

@implementation PLLayoutView

@synthesize filledThumbs;
@synthesize mouseTool;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // Initialization code here.
        filledThumbs = 0;
        layoutMatrixHeight = 0;
        layoutMatrixWidth = 0;
        isDraggingDestination = NO;
        currentInsertingIndex = -1;
        draggedThumbnailIndex = -1;
        previousLeftShrink = -1;
        previousRightShrink = -1;
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSTIFFPboardType, pasteBoardOsiriX, nil]];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (isDraggingDestination)
    {
        [NSBezierPath setDefaultLineWidth:3.0];
        [[NSColor blueColor] setStroke];
        [[NSColor colorWithCalibratedWhite:0.65 alpha:1] setFill];
    }
    else
    {
        [NSBezierPath setDefaultLineWidth:1.0];
        [[NSColor blackColor] setStroke];
        [[NSColor grayColor] setFill];
    }
    
    [NSBezierPath bezierPathWithRect:self.bounds];
    [NSBezierPath fillRect:self.bounds];
    [NSBezierPath strokeRect:self.bounds];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#pragma mark-Setters/Getters

- (int)mouseTool
{
    return mouseTool;
}

- (void)setMouseTool:(int)currentTool
{
    NSUInteger nbSubviews = [[self subviews] count];
    for (NSUInteger i = 0; i < nbSubviews; ++i)
    {
        [[[self subviews] objectAtIndex:i] setCurrentTool:currentTool];
    }
}

#pragma mark-Drag'n'Drop
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    if (([[sender draggingPasteboard] dataForType:pasteBoardOsiriX] || [NSImage canInitWithPasteboard:[sender draggingPasteboard]]) &&
        [sender draggingSourceOperationMask] & NSDragOperationCopy)
    {
        isDraggingDestination = YES;
        [self setNeedsDisplay:YES];
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    if (!(([[sender draggingPasteboard] dataForType:pasteBoardOsiriX] || [NSImage canInitWithPasteboard:[sender draggingPasteboard]]) &&
          [sender draggingSourceOperationMask] & NSDragOperationCopy))
    {
        return NSDragOperationNone;
    }
    
    NSUInteger nbSubviews = [[self subviews] count];
    if (nbSubviews)
    {
        NSUInteger margin = 10; // percentage
        NSPoint p = [sender draggingLocation];
        int index = [self inThumbnailView:[sender draggingLocation] margin:0];
        
        if (index > -1) // there is a view under the pointer
        {
            PLThumbnailView *pointedView = [[self subviews] objectAtIndex:index];
            if ([self inThumbnailView:p margin:margin] == -1 && [pointedView curDCM])
                // the pointer is in the thumb's margin and there's an image in the thumb
            {
                pointedView.isDraggingDestination = NO;
                if (draggedThumbnailIndex != index)
                {
                    for (int i = 0; i < nbSubviews; ++i)
                    {
                        [[[self subviews] objectAtIndex:i] setIsDraggingDestination:NO];
                    }
                    
                    NSPoint q = [pointedView convertPoint:p fromView:nil];
                    if ([pointedView originalFrame].size.width - q.x > q.x)
                        // left margin
                    {
                        if ([pointedView shrinking] != left)
                        {
                            if (previousLeftShrink != -1)
                                [[[self subviews] objectAtIndex:previousLeftShrink] backToOriginalSize];
                            
                            if ([pointedView shrinking] == none)
                            {
                                if (previousRightShrink != -1)
                                    [[[self subviews] objectAtIndex:previousRightShrink] backToOriginalSize];
                            }
                            else
                            {
                                [pointedView backToOriginalSize];
                            }
                            
                            [pointedView shrinkWidth:margin onIts:left];
                            previousLeftShrink = index;
                            
                            if (index % layoutMatrixWidth)
                            {
                                [[[self subviews] objectAtIndex:index - 1] shrinkWidth:margin onIts:right];
                                previousRightShrink = index - 1;
                            }
                            currentInsertingIndex = index;
                        }
                    }
                    else
                        // right margin
                    {
                        if ([pointedView shrinking] != right)
                        {
                            if (previousRightShrink != -1)
                                [[[self subviews] objectAtIndex:previousRightShrink] backToOriginalSize];
                            
                            if ([pointedView shrinking] == none)
                            {
                                if (previousLeftShrink != -1)
                                    [[[self subviews] objectAtIndex:previousLeftShrink] backToOriginalSize];
                            }
                            else
                            {
                                [pointedView backToOriginalSize];
                            }
                            
                            [pointedView shrinkWidth:margin onIts:right];
                            previousRightShrink = index;
                            
                            if (index % layoutMatrixWidth != layoutMatrixWidth - 1 && index != nbSubviews - 1)
                            {
                                [[[self subviews] objectAtIndex:index + 1] shrinkWidth:margin onIts:left];
                                previousLeftShrink = index + 1;
                            }
                            currentInsertingIndex = index + 1;
                        }
                    }
                }   
            }
            else // the pointer is in the thumb's center 
            {
                currentInsertingIndex = index;
                for (int i = 0; i < nbSubviews; ++i)
                {
                    PLThumbnailView *thumbView = [[self subviews] objectAtIndex:i];
                    thumbView.isDraggingDestination = NO;

                    if ([thumbView shrinking] == left || [thumbView shrinking] == right)
                    {
                        [thumbView backToOriginalSize];
                    }
                    previousLeftShrink = -1;
                    previousRightShrink = -1;
                }
                pointedView.isDraggingDestination = YES;
            }
        }
    }
    [self setNeedsDisplay:YES];

    return NSDragOperationCopy;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    isDraggingDestination = NO;
    
    NSUInteger nbSubviews = [[self subviews] count];
    for (NSUInteger i = 0; i < nbSubviews; ++i)
    {
        PLThumbnailView *thumbView = [[self subviews] objectAtIndex:i];
        thumbView.isDraggingDestination = NO;
        
        if ([thumbView shrinking] == left || [thumbView shrinking] == right)
        {
            [thumbView backToOriginalSize];
        }
    }
    previousLeftShrink = -1;
    previousRightShrink = -1;
    currentInsertingIndex = -1;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if ([[sender draggingPasteboard] dataForType:pasteBoardOsiriX] || [NSImage canInitWithPasteboard:[sender draggingPasteboard]])
    // Check that the pasteboard contains an image
    {
        if (![[self subviews] count])
        // Create a 1x1 layout if the layout is still empty
        {
            [self updateLayoutViewWidth:1 height:1];
            [[[self subviews] objectAtIndex:0] fillViewWith:[sender draggingPasteboard]];
            ++filledThumbs;
            return YES;
        }
        
        int i = [self inThumbnailView:[sender draggingLocation] margin:10];
        if (draggedThumbnailIndex != -1)
        // Drag'n'drop between printing layout subviews
        {
            if (draggedThumbnailIndex != i)
            {
                [[[self subviews] objectAtIndex:draggedThumbnailIndex] setImage:nil];
                --filledThumbs;
            }
            draggedThumbnailIndex = -1;
        }
        
        // Insert the pasteboard
        if (i != -1)
        // If the destination is the center of the thumbnail, just replace the current data.
        {
            PLThumbnailView *thumb = [[self subviews] objectAtIndex:i];
            if (![thumb curDCM])
            {
                ++filledThumbs;;
            }
            [thumb fillViewWith:[sender draggingPasteboard]];
        }
        else
        // If the destination is the margin of the thumbnail, insert the data to the proper thumbnail.
        {
            // Check if there is enough - available, i.e. empty - thumbnail views to insert a new one
            while ([[self subviews] count] <= filledThumbs)
            {
                if (layoutMatrixHeight < layoutMatrixWidth)
                {
                    ++layoutMatrixHeight;
                }
                else
                {
                    ++layoutMatrixWidth;
                }
                [self updateLayoutViewWidth:layoutMatrixWidth height:layoutMatrixHeight];
            }
            [self insertImageAtIndex:currentInsertingIndex from:sender];
        }
    }
    return YES;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
    previousLeftShrink = -1;
    previousRightShrink = -1;
    currentInsertingIndex = -1;
    draggedThumbnailIndex = -1;
    isDraggingDestination = NO;
    [self reorderLayoutMatrix];
    [self resizeLayoutView];
    
    NSUInteger nbSubviews = [[self subviews] count];
    for (NSUInteger i = 0; i < nbSubviews; ++i)
    {
        [[[self subviews] objectAtIndex:i] setIsDraggingDestination:NO];
    }
    [self setNeedsDisplay:YES];
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    switch(context)
    {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationNone;
            
        case NSDraggingContextWithinApplication:
        default:
            return NSDragOperationCopy;
    }
}

#pragma mark-Events handling
- (void)mouseDown:(NSEvent *)theEvent
{
    int index = [self inThumbnailView:[theEvent locationInWindow] margin:0];

    if (index > -1 && index < [[self subviews] count])
    {
        draggedThumbnailIndex = index;
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    int index = [self inThumbnailView:[theEvent locationInWindow] margin:0];
    
    if (draggedThumbnailIndex == index && index > -1 && index < [[self subviews] count])
    {
        PLThumbnailView *thumb = [[self subviews] objectAtIndex:index];
        thumb.isSelected = !thumb.isSelected;
        [self setNeedsDisplay:YES];
    }
    draggedThumbnailIndex = -1;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if (draggedThumbnailIndex > -1 && draggedThumbnailIndex < [[self subviews] count])
    {
//        PLThumbnailView *thumb = [[self subviews] objectAtIndex:draggedThumbnailIndex];
        NSImage *draggedImage = nil;//thumb.image;
        if (draggedImage)
        {
            [draggedImage setSize:NSMakeSize(50, 50)];
            NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
            [pasteboard declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:self];
            [pasteboard setData:[draggedImage TIFFRepresentation] forType:NSTIFFPboardType];
            [self dragImage:draggedImage at:[self convertPoint:[theEvent locationInWindow] fromView:nil] offset:NSMakeSize(0, 0) event:theEvent pasteboard:pasteboard source:self slideBack:YES];
        }
    }
}

- (void)keyDown:(NSEvent *)theEvent
{
    if ([[theEvent characters] length] == 0)
        return;
    
    unichar c = [[theEvent characters] characterAtIndex:0];
    if (c == NSBackspaceCharacter || c == NSDeleteCharacter)
    {
        NSUInteger nbSubviews = [[self subviews] count];
        for (NSUInteger i = 0; i < nbSubviews; ++i)
        {
            PLThumbnailView *thumb = [[self subviews] objectAtIndex:i];
            if (thumb.isSelected && [thumb curDCM])
            {
                [[thumb dcmPixList]     release];
                [[thumb dcmRoiList]     release];
                [[thumb dcmFilesList]   release];
                --filledThumbs;
            }
            thumb.isSelected = NO;
        }
    }

    [self setNeedsDisplay:YES];
}


#pragma mark-Layout management
- (void)updateLayoutViewWidth:(NSUInteger)w height:(NSUInteger)h
{
    NSUInteger newSize = w * h;
    if (newSize < filledThumbs)
    {
        NSRunAlertPanel(NSLocalizedString(@"Layout Error", nil), NSLocalizedString(@"There are too many views in your layout for you to choose the selected layout.", nil), NSLocalizedString(@"OK", nil), nil, nil);
        return;
    }
    
    NSUInteger currentSize = [[self subviews] count];
    layoutMatrixWidth = w;
    layoutMatrixHeight = h;
    if (currentSize)
    {
        // If the new layout has more thumbnails than the previous one
        if (currentSize < newSize)
        {
            while ([[self subviews] count] < newSize)
            {
                [self addSubview:[[PLThumbnailView alloc] init]];
            }
        }
        // If the new layout has less thumbnails than the previous one
        else
        {
            NSUInteger i = 0;
            while ([[self subviews] count] > newSize)
            {
                PLThumbnailView * thumb = [[self subviews] objectAtIndex:i];
                if (![thumb curDCM])
                {
                    [thumb removeFromSuperview];
                }
                else
                {
                    ++i;
                }
            }
        }
    }
    // If the layout was not defined before
    else
    {
        NSRect r = [self bounds];
        NSSize viewSize = r.size;
        CGFloat x = viewSize.width / w;
        CGFloat y = viewSize.height / h;
        for (NSUInteger i = 0 ; i < w; ++i)
        {
            for (NSUInteger j = 0; j < h; ++j)
            {
                // (0,0) is the bottom left corner of the view, while the thumbnails are ordered in the reading direction (from upper left to bottom right)
                NSUInteger xOrigin = roundf(x * i);
                NSUInteger yOrigin = roundf(viewSize.height - y*(j+1));
                NSRect frame = NSMakeRect(xOrigin, yOrigin, roundf(x*(i+1)) - xOrigin, roundf(viewSize.height - y*j) - yOrigin);
                PLThumbnailView * v = [[PLThumbnailView alloc] initWithFrame:frame];
                [self addSubview:v];
            }
        }
    }
    [self setNeedsDisplay:YES];
}

- (void)reorderLayoutMatrix
{
    NSUInteger nbSubs = [[self subviews] count];
    for (NSUInteger i = 0; i < nbSubs; ++i)
    {
        PLThumbnailView *thumb = [[self subviews] objectAtIndex:i];
        thumb.isSelected = NO;
    }
}

- (void)resizeLayoutView
{
    NSRect r = [self bounds];
    NSSize viewSize = r.size;
    CGFloat x = viewSize.width / layoutMatrixWidth;
    CGFloat y = viewSize.height / layoutMatrixHeight;
    for (NSUInteger i = 0 ; i < layoutMatrixWidth; ++i)
    {
        for (NSUInteger j = 0; j < layoutMatrixHeight; ++j)
        {
            // (0,0) is the bottom left corner of the view, while the thumbnails are ordered in the european reading direction (from upper left to bottom right)
            NSUInteger xOrigin = roundf(x*i);
            NSUInteger yOrigin = roundf(viewSize.height-y*(j+1));
            NSRect frame = NSMakeRect(xOrigin, yOrigin, roundf(x*(i+1)-xOrigin), roundf(viewSize.height-y*(j))-yOrigin);
            [[[self subviews] objectAtIndex:i+j*layoutMatrixWidth] setFrame:frame];
            [[[self subviews] objectAtIndex:i+j*layoutMatrixWidth] setOriginalFrame:frame];
        }
    }
}

- (void)clearAllThumbnailsViews
{
    NSUInteger nbSubviews = [[self subviews] count];
    for (NSUInteger i = 0 ; i < nbSubviews; ++i)
    {
        PLThumbnailView *thumb = [[self subviews] objectAtIndex:i];
        [[thumb dcmPixList]     release];
        [[thumb dcmRoiList]     release];
        [[thumb dcmFilesList]   release];
        thumb.isSelected = NO;
    }
    filledThumbs = 0;
    [self setNeedsDisplay:YES];
}

- (int)inThumbnailView:(NSPoint)p margin:(NSUInteger)size
{
    NSUInteger nbSubviews = [[self subviews] count];
    for (int i = 0; i < nbSubviews; ++i)
    {
        PLThumbnailView *thumb = [[self subviews] objectAtIndex:i];
        NSPoint q = [self convertPoint:p fromView:nil];
        NSUInteger m = thumb.originalFrame.size.width * size / 100;
        NSRect inFrame = thumb.originalFrame;
        if (q.x >= inFrame.origin.x + m && q.y >= inFrame.origin.y &&
            q.x < inFrame.origin.x + inFrame.size.width - m && q.y < inFrame.origin.y + inFrame.size.height)
        {
            return i;
        }
    }
    return -1;
}

- (int)getSubviewInsertIndexFrom:(NSPoint)p
{
    int currentView = [self inThumbnailView:p margin:0];
    if (currentView > -1 && currentView < [[self subviews] count])
    {
        PLThumbnailView *thumb = [[self subviews] objectAtIndex:currentView];
        NSPoint q = [thumb convertPoint:p fromView:nil];
        NSRect inFrame = [thumb originalFrame];
        if (inFrame.size.width - q.x < q.x && currentView < [[self subviews] count] - 1)
        {
            return currentView + 1;
        }
        else
        {
            return currentView;
        }
    }
    else
    {
        return  -1;
    }
}

- (void)insertImageAtIndex:(NSUInteger)n from:(id<NSDraggingInfo>)sender
{
    NSUInteger index = MIN([[self subviews] count]-1, n);

    PLThumbnailView *thumb = [[self subviews] objectAtIndex:index];
    ++filledThumbs;
    if (![thumb curDCM])
    {
        [thumb fillViewWith:[sender draggingPasteboard]];
        return;
    }
    
    int i = [self findNextEmptyViewFrom:index];
    if (i < 0)
        return;

    if (i > index)
    {
        for (NSUInteger j = i; j > index; --j)
        {
//            [[[self subviews] objectAtIndex:j] setImage:[[[self subviews] objectAtIndex:j-1] image]];
            PLThumbnailView *thumb = [[self subviews] objectAtIndex:j-1];
            NSMutableArray *pList = [thumb dcmPixList];
            NSMutableArray *rList = [thumb dcmRoiList];
            NSArray *fList = [thumb dcmFilesList];
            [[[self subviews] objectAtIndex:j] setPixels:pList files:fList rois:rList firstImage:0 level:'i' reset:YES];
        }
        [thumb fillViewWith:[sender draggingPasteboard]];
    }
    else// if (i < index)
    {
        for (NSUInteger j = i; j < n-1; ++j) // n i.o. index because if n == [[self subviews] count], thummb is not inserted at last position
        {
//            [[[self subviews] objectAtIndex:j] setImage:[[[self subviews] objectAtIndex:j+1] image]];
            PLThumbnailView *thumb = [[self subviews] objectAtIndex:j+1];
            NSMutableArray *pList = [thumb dcmPixList];
            NSMutableArray *rList = [thumb dcmRoiList];
            NSArray *fList = [thumb dcmFilesList];
            [[[self subviews] objectAtIndex:j] setPixels:pList files:fList rois:rList firstImage:0 level:'i' reset:YES];
        }
        [[[self subviews] objectAtIndex:n-1] fillViewWith:[sender draggingPasteboard]];
    }
}

- (int)findNextEmptyViewFrom:(NSUInteger)index
{
    int i;
    NSUInteger nbSubviews = [[self subviews] count];
    
    for (i = index; i < nbSubviews; ++i)
    {
        if (![[[self subviews] objectAtIndex:i] curDCM])
        {
            return i;
        }
    }
    for (i = index - 1; i >= 0; --i)
    {
        if (![[[self subviews] objectAtIndex:i] curDCM])
        {
            return i;
        }
    }
    return -1;
}

- (void)saveLayoutViewToDicom
{
    NSBitmapImageRep *bitmapImageRep = [self bitmapImageRepForCachingDisplayInRect:[self bounds]];
    [self cacheDisplayInRect:[self bounds] toBitmapImageRep:bitmapImageRep];
    
    NSInteger bytesPerPixel = [bitmapImageRep bitsPerPixel] / 8;
//	CGFloat backgroundRGBA[4];
//  [[backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] getComponents:backgroundRGBA];

//	// convert RGBA to RGB - alpha values are considered when mixing the background color with the actual pixel color
	NSMutableData* bitmapRGBData = [NSMutableData dataWithCapacity: [bitmapImageRep size].width*[bitmapImageRep size].height*3];
	for (int y = 0; y < [bitmapImageRep size].height; ++y) {
		unsigned char* rowStart = [bitmapImageRep bitmapData]+[bitmapImageRep bytesPerRow]*y;
		for (int x = 0; x < [bitmapImageRep size].width; ++x) {
			unsigned char rgba[4];
            memcpy(rgba, rowStart+bytesPerPixel*x, 4);
//			float ratio = ((float)rgba[3])/255;
			// rgba[0], [1] and [2] are premultiplied by [3]
//			rgba[0] = rgba[0]+(1-ratio)*backgroundRGBA[0]*255;
//			rgba[1] = rgba[1]+(1-ratio)*backgroundRGBA[1]*255;
//			rgba[2] = rgba[2]+(1-ratio)*backgroundRGBA[2]*255;
			[bitmapRGBData appendBytes:rgba length:3];
		}
	}
    
    DICOMExport *dicomExport = [[DICOMExport alloc] init];
    
//	[dicomExport setSourceFile:[[[_viewer pixList] objectAtIndex:0] srcFile]];
//	[dicomExport setSeriesDescription: seriesDescription];
	[dicomExport setSeriesNumber: 35466];
	[dicomExport setPixelData:(unsigned char*)[bitmapRGBData bytes] samplePerPixel:3 bitsPerPixel:8 width:[bitmapImageRep size].width height:[bitmapImageRep size].height];
    
    // Save view as a DICOM file and store it in the local db
//	NSString* f = [dicomExport writeDCMFile:nil];
//
//	if (f)
//		[BrowserController addFiles: [NSArray arrayWithObject: f]
//                          toContext: [[BrowserController currentBrowser] managedObjectContext]
//                         toDatabase: [BrowserController currentBrowser]
//                          onlyDICOM: YES
//                   notifyAddedFiles: YES
//                parseExistingObject: YES
//                           dbFolder: [[BrowserController currentBrowser] documentsDirectory]
//                  generatedByOsiriX: YES];
	
	[dicomExport release];

    
    NSImage *image = [[NSImage alloc] init];
    [image addRepresentation:bitmapImageRep];
    [[image TIFFRepresentation] writeToFile:@"/Users/bd/Downloads/view.tiff" atomically:YES];
    [image release];
}

@end



























































