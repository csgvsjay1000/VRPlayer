//
//  VRPlayer.m
//  VRPlayer
//
//  Created by chengshenggen on 7/19/16.
//  Copyright © 2016 Gan Tian. All rights reserved.
//

#import "VRPlayer.h"
#import "AAPLEAGLLayer.h"
#import "VRPlayerHeader.h"
#import "KBPlayerEnumHeaders.h"

@interface VRPlayer (){
    FILE *_file;
}

@property(nonatomic,strong)AAPLEAGLLayer *appleGLLayer;

@property(nonatomic,copy)NSString *urlStr;

@property(nonatomic,assign)VideoState *is;
@property(nonatomic,strong)NSThread *read_tid;
@property(nonatomic,strong)NSThread *videoThread;
@property(nonatomic,strong)NSThread *audioThread;
@property(nonatomic,assign)KBPlayerPlayingState playingState;  //播放状态


@end


@implementation VRPlayer

-(id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self.layer addSublayer:self.appleGLLayer];
    }
    return self;
}

-(void)dealloc{
    NSLog(@"%@ dealloc",[self class]);
}


#pragma mark - player manager
-(void)preparePlay{
    _urlStr = [[NSBundle mainBundle] pathForResource:@"cuc_ieschool" ofType:@"flv"];
    _is = malloc(sizeof(VideoState));
    pthread_mutex_init(&_is->pictq_mutex, NULL);
    pthread_cond_init(&_is->pictq_cond, NULL);
    [self schedule_refresh:40];
    _read_tid = [[NSThread alloc] initWithTarget:self selector:@selector(read_thread) object:nil];
    _read_tid.name = @"com.3glasses.vrshow.read";
    [_read_tid start];
}

-(void)play{
    
}

-(void)pause{
    
}

#pragma mark - read thread
-(void)read_thread{
    
    _is->audio_stream = -1;
    _is->video_stream = -1;
    
    int bufSize = 512;
    uint8_t *buf = malloc(sizeof(uint8_t)*bufSize);
    
    _file = fopen([_urlStr UTF8String], "rb");
//    fread(buf, sizeof(uint8_t), bufSize, _file);
    FLV_HEADER flv_header = [self flv_prob];
    //存在音频
    if (flv_header.Flags>>2 == 1) {
        
        if ((flv_header.Flags&0x01) == 1) {
            //存在视频
            _is->audio_stream = TAG_TYPE_AUDIO;
            _is->video_stream = TAG_TYPE_VIDEO;
        }else{
            printf("Flags: Audio \n");
            _is->audio_stream = TAG_TYPE_AUDIO;
        }
    }
    if (_is->video_stream>=0) {
        [self video_stream_component_open];
    }
    AVPacket *packet;
    packet=(AVPacket *)malloc(sizeof(AVPacket));
    
    fseek(_file, CFSwapInt32BigToHost(flv_header.DataOffset), SEEK_SET);

    for (; ; ) {
        if (_is->videoq.size > MAX_VIDEOQ_SIZE) {
            printf(" videoq.size %d\n",_is->videoq.size);
            usleep(10*1000);
            continue;
        }
        if ([self av_read_frame:packet]>=0) {
            if (packet->stream_index == _is->video_stream) {
                printf(" video.size %d\n",packet->size);
                packet_queue_put(&_is->videoq, packet);
            }else if (packet->stream_index == _is->audio_stream){
                printf(" audio.size %d\n",packet->size);
//                packet_queue_put(&_is->, packet);
            }
        }else{
            break;
        }
    }
    
}

-(int)av_read_frame:(AVPacket *)packet{
    uint previoustagsize = 0;
    previoustagsize =  CFSwapInt32BigToHost(getw(_file));
    
    TAG_HEADER tagheader;
    fread((void *)&tagheader,sizeof(TAG_HEADER),1,_file);
    int tagheader_datasize=tagheader.DataSize[0]*65536+tagheader.DataSize[1]*256+tagheader.DataSize[2];
    int tagheader_timestamp=tagheader.Timestamp[0]*65536+tagheader.Timestamp[1]*256+tagheader.Timestamp[2];
    packet->stream_index = tagheader.TagType;
    
    packet->data = malloc(tagheader_datasize);
    size_t read_size = fread(packet->data, sizeof(uint8_t), tagheader_datasize, _file);
    packet->size = read_size;
    packet->pts = tagheader_timestamp;
    if (read_size == tagheader_datasize) {
        
    }else if (read_size<=0){
        if (feof(_file)) {
            //读流结束
            return -1;
        }
    }
    if (tagheader.TagType == TAG_TYPE_AUDIO) {
        //音频
        
    }else if (tagheader.TagType == TAG_TYPE_VIDEO) {
        //视频
        
    }else if (tagheader.TagType == TAG_TYPE_SCRIPT) {
        //SCRIPT
        
    }else{
        
        printf("UNKNOWN\n");
    }
    
    
    return 0;
}

-(void)video_stream_component_open{
    packet_queue_init(&_is->videoq);
    _videoThread = [[NSThread alloc] initWithTarget:self selector:@selector(playVideoThread) object:nil];
    _videoThread.name = @"com.3glasses.vrshow.video";
    [_videoThread start];

}

-(void)audio_stream_component_open{
    packet_queue_init(&_is->audioq);
    _audioThread = [[NSThread alloc] initWithTarget:self selector:@selector(playAudioThread) object:nil];
    _audioThread.name = @"com.3glasses.vrshow.audio";
    [_audioThread start];
}

-(void)playVideoThread{
    
}

-(void)playAudioThread{
    
}

-(void)schedule_refresh:(int)delay{
    
    

}

#pragma mark - private methods
-(FLV_HEADER)flv_prob{
    FLV_HEADER flv_header;
    fseek(_file, 0, SEEK_SET);
    fread(&flv_header, 1, sizeof(FLV_HEADER), _file);
    
    if (flv_header.Signature[0] == 'F' && flv_header.Signature[1] == 'L' && flv_header.Signature[2] == 'V') {
        printf("Format: FLV\n");
    }
    printf("Version: %d\n",flv_header.Version);
    
    //存在音频
    if (flv_header.Flags>>2 == 1) {
        
        if ((flv_header.Flags&0x01) == 1) {
            //存在视频
            printf("Flags: Audio Video\n");
        }else{
            printf("Flags: Audio \n");
        }
    }else{
        printf("Flags: None \n");
    }
    printf("DataOffset: %d \n",CFSwapInt32BigToHost(flv_header.DataOffset));
    return flv_header;
}

#pragma mark - setters and getters
-(AAPLEAGLLayer *)appleGLLayer{
    if (_appleGLLayer == nil) {
        _appleGLLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.bounds];
    }
    return _appleGLLayer;
}

@end
