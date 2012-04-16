//
//  TilesViewController.m
//  Tiles
//

#import "TilesViewController.h"
#import "Tile.h"
#import <QuartzCore/QuartzCore.h>


#define TILE_WIDTH  57
#define TILE_HEIGHT TILE_WIDTH
#define TILE_MARGIN 18


@interface TilesViewController ()
- (void)createTiles;
- (CALayer *)layerForTouch:(UITouch *)touch;
- (void)touchBegan:(UITouch *)touch forTile:(Tile *)tile;
- (int)frameIndexForTileIndex:(int)tileIndex;
- (void)moveHeldTileToPoint:(CGPoint)location;
- (void)moveUnheldTilesAwayFromPoint:(CGPoint)location;
- (int)indexOfClosestFrameToPoint:(CGPoint)point;
- (void)startTilesWiggling;
- (void)stopTilesWiggling;
@end


@implementation TilesViewController


#pragma mark -
#pragma mark Initialization


- (void)viewDidLoad {
    [super viewDidLoad];
    [self createTiles];
}


- (void)createTiles {
    UIColor *tileColors[] = {
        [UIColor blueColor],
        [UIColor brownColor],
        [UIColor grayColor],
        [UIColor greenColor],
        [UIColor orangeColor],
        [UIColor purpleColor],
        [UIColor redColor],
    };
    int tileColorCount = sizeof(tileColors) / sizeof(tileColors[0]);
    
    for (int row = 0; row < TILE_ROWS; ++row) {
        for (int col = 0; col < TILE_COLUMNS; ++col) {
            int index = (row * TILE_COLUMNS) + col;
            
            CGRect frame = CGRectMake(TILE_MARGIN + col * (TILE_MARGIN + TILE_WIDTH),
                                      TILE_MARGIN + row * (TILE_MARGIN + TILE_HEIGHT),
                                      TILE_WIDTH, TILE_HEIGHT);
            tileFrame[index] = frame;
            
            Tile *tile = [[Tile alloc] init];
            tile.tileIndex = index;
            tileForFrame[index] = tile;
            tile.frame = frame;
            tile.backgroundColor = tileColors[index % tileColorCount].CGColor;
            tile.cornerRadius = 8;
            tile.delegate = self;
            if ([tile respondsToSelector:@selector(setContentsScale:)])
            {
                tile.contentsScale = [[UIScreen mainScreen] scale];
            }                    
            [self.view.layer addSublayer:tile];
            [tile setNeedsDisplay];
            [tile release];
        }
    }
}


#pragma mark -
#pragma mark Layer delegate methods


- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if ([layer isKindOfClass:[Tile class]]) {
        Tile *tile = (Tile *)layer;
        UIGraphicsPushContext(ctx);
        [tile draw];
        UIGraphicsPopContext();
    }
}


#pragma mark -
#pragma mark touchesBegan


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CALayer *hitLayer = [self layerForTouch:touch];
    if ([hitLayer isKindOfClass:[Tile class]]) {
        [self touchBegan:touch forTile:(Tile*)hitLayer];
    }
}


- (CALayer *)layerForTouch:(UITouch *)touch {
    UIView *view = self.view;
    
    CGPoint location = [touch locationInView:view];
    location = [view convertPoint:location toView:nil];
    
    CALayer *hitPresentationLayer = [view.layer.presentationLayer hitTest:location];
    if (hitPresentationLayer) {
        return hitPresentationLayer.modelLayer;
    }
    
    return nil;
}


- (void)touchBegan:(UITouch *)touch forTile:(Tile *)tile {
    heldTile = tile;
    
    touchStartLocation = [touch locationInView:self.view];
    heldStartPosition = tile.position;
    heldFrameIndex = [self frameIndexForTileIndex:tile.tileIndex];
    
    [tile moveToFront];
    [tile appearDraggable];
    [self startTilesWiggling];
}


- (int)frameIndexForTileIndex:(int)tileIndex {
    for (int i = 0; i < TILE_COUNT; ++i) {
        if (tileForFrame[i].tileIndex == tileIndex) {
            return i;
        }
    }
    return 0;
}


#pragma mark -
#pragma mark touchesMoved


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (heldTile) {
        UITouch *touch = [touches anyObject];
        UIView *view = self.view;
        CGPoint location = [touch locationInView:view];
        [self moveHeldTileToPoint:location];
        [self moveUnheldTilesAwayFromPoint:location];
    }
}


- (void)moveHeldTileToPoint:(CGPoint)location {
    float dx = location.x - touchStartLocation.x;
    float dy = location.y - touchStartLocation.y;
    CGPoint newPosition = CGPointMake(heldStartPosition.x + dx, heldStartPosition.y + dy);
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    heldTile.position = newPosition;
    [CATransaction commit];
}


- (void)moveUnheldTilesAwayFromPoint:(CGPoint)location {
    int frameIndex = [self indexOfClosestFrameToPoint:location];
    if (frameIndex != heldFrameIndex) {
        [CATransaction begin];
        
        if (frameIndex < heldFrameIndex) {
            for (int i = heldFrameIndex; i > frameIndex; --i) {
                Tile *movingTile = tileForFrame[i-1];
                movingTile.frame = tileFrame[i];
                tileForFrame[i] = movingTile;
            }
        }
        else if (heldFrameIndex < frameIndex) {
            for (int i = heldFrameIndex; i < frameIndex; ++i) {
                Tile *movingTile = tileForFrame[i+1];
                movingTile.frame = tileFrame[i];
                tileForFrame[i] = movingTile;
            }
        }
        heldFrameIndex = frameIndex;
        tileForFrame[heldFrameIndex] = heldTile;
        
        [CATransaction commit];
    }
}


- (int)indexOfClosestFrameToPoint:(CGPoint)point {
    int index = 0;
    float minDist = FLT_MAX;
    for (int i = 0; i < TILE_COUNT; ++i) {
        CGRect frame = tileFrame[i];
        
        float dx = point.x - CGRectGetMidX(frame);
        float dy = point.y - CGRectGetMidY(frame);
        
        float dist = (dx * dx) + (dy * dy);
        if (dist < minDist) {
            index = i;
            minDist = dist;
        }
    }
    return index;
}


#pragma mark -
#pragma mark touchesEnded


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (heldTile) {
        [heldTile appearNormal];
        heldTile.frame = tileFrame[heldFrameIndex];
        heldTile = nil;
        [self stopTilesWiggling];
    }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}


#pragma mark -
#pragma mark Tile animation


- (void)startTilesWiggling {
    for (int i = 0; i < TILE_COUNT; ++i) {
        Tile *tile = tileForFrame[i];
        if (tile != heldTile) {
            [tile startWiggling];
        }
    }
}


- (void)stopTilesWiggling {
    for (int i = 0; i < TILE_COUNT; ++i) {
        Tile *tile = tileForFrame[i];
        [tile stopWiggling];
    }
}


@end
