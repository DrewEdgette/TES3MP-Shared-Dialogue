#include <osg/Image>
#include <osgDB/ReadFile>
#include <osgDB/WriteFile>
#include <osgText/Font>
#include <AL/al.h>
#include <AL/alc.h>
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/channel_layout.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

void require(bool ok, const std::string& message)
{
    if (!ok) throw std::runtime_error(message);
}

void checkImages(const std::string& directory, const std::string& fontPath)
{
    osg::ref_ptr<osg::Image> image = new osg::Image;
    image->allocateImage(8, 8, 1, GL_RGB, GL_UNSIGNED_BYTE);
    std::memset(image->data(), 120, image->getTotalSizeInBytes());
    for (const auto* extension : {"png", "jpg", "bmp", "tga", "dds"})
    {
        const auto file = directory + "/roundtrip." + extension;
        require(osgDB::writeImageFile(*image, file), "Cannot write " + file);
        const auto decoded = osgDB::readRefImageFile(file);
        require(decoded && decoded->s() == 8 && decoded->t() == 8, "Cannot read " + file);
        std::cout << extension << " image round trip passed\n";
    }
    require(osgText::readRefFontFile(fontPath).valid(), "FreeType font loading failed");
    osg::ref_ptr<osg::Group> group = new osg::Group;
    const auto scene = directory + "/roundtrip.osgb";
    require(osgDB::writeNodeFile(*group, scene), "OSG scene serialization failed");
    require(osgDB::readRefNodeFile(scene).valid(), "OSG scene loading failed");
    std::cout << "FreeType font and OSG serializer checks passed\n";
}

void checkAudio()
{
    auto* device = alcOpenDevice(nullptr);
    require(device != nullptr, "OpenAL device failed");
    auto* context = alcCreateContext(device, nullptr);
    require(context && alcMakeContextCurrent(context), "OpenAL context failed");
    ALuint buffer;
    alGenBuffers(1, &buffer);
    const short samples[64] = {};
    alBufferData(buffer, AL_FORMAT_MONO16, samples, sizeof(samples), 22050);
    require(alGetError() == AL_NO_ERROR, "OpenAL buffer failed");
    alDeleteBuffers(1, &buffer);
    alcMakeContextCurrent(nullptr);
    alcDestroyContext(context);
    alcCloseDevice(device);
    std::cout << "OpenAL context and sample buffer passed\n";
}

void checkMedia(const std::string& path)
{
    AVFormatContext* format = nullptr;
    require(avformat_open_input(&format, path.c_str(), nullptr, nullptr) >= 0, "Cannot open media: " + path);
    require(avformat_find_stream_info(format, nullptr) >= 0, "Cannot inspect media streams");
    std::vector<AVCodecContext*> codecs(format->nb_streams, nullptr);
    std::vector<int> decoded(format->nb_streams, 0);
    for (unsigned i = 0; i < format->nb_streams; ++i)
    {
        const auto* parameters = format->streams[i]->codecpar;
        if (parameters->codec_type != AVMEDIA_TYPE_VIDEO && parameters->codec_type != AVMEDIA_TYPE_AUDIO) continue;
        const auto* codec = avcodec_find_decoder(parameters->codec_id);
        require(codec != nullptr, "Missing media decoder");
        codecs[i] = avcodec_alloc_context3(codec);
        require(codecs[i] && avcodec_parameters_to_context(codecs[i], parameters) >= 0
            && avcodec_open2(codecs[i], codec, nullptr) >= 0, "Cannot initialize media decoder");
    }
    AVPacket* packet = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    for (int count = 0; count < 200 && av_read_frame(format, packet) >= 0; ++count)
    {
        const auto index = packet->stream_index;
        auto* codec = codecs[index];
        if (codec)
        {
            require(avcodec_send_packet(codec, packet) >= 0, "Decoder rejected a media packet");
            int result;
            while ((result = avcodec_receive_frame(codec, frame)) >= 0)
            {
                if (decoded[index]++ == 0 && codec->codec_type == AVMEDIA_TYPE_VIDEO)
                {
                    auto* scaler = sws_getContext(frame->width, frame->height, static_cast<AVPixelFormat>(frame->format),
                        8, 8, AV_PIX_FMT_RGBA, SWS_BILINEAR, nullptr, nullptr, nullptr);
                    require(scaler != nullptr, "Video conversion initialization failed");
                    unsigned char pixels[8 * 8 * 4];
                    unsigned char* destination[] = {pixels};
                    int strides[] = {8 * 4};
                    require(sws_scale(scaler, frame->data, frame->linesize, 0, frame->height, destination, strides) == 8,
                        "Video conversion failed");
                    sws_freeContext(scaler);
                }
                else if (decoded[index] == 1 && codec->codec_type == AVMEDIA_TYPE_AUDIO)
                {
                    auto layout = frame->channel_layout ? frame->channel_layout : av_get_default_channel_layout(frame->channels);
                    auto* resampler = swr_alloc_set_opts(nullptr, AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, 44100,
                        layout, static_cast<AVSampleFormat>(frame->format), frame->sample_rate, 0, nullptr);
                    require(resampler && swr_init(resampler) >= 0, "Audio resampling initialization failed");
                    std::vector<unsigned char> samples(4 * (frame->nb_samples * 44100 / frame->sample_rate + 256));
                    unsigned char* destination[] = {samples.data()};
                    require(swr_convert(resampler, destination, static_cast<int>(samples.size() / 4),
                        const_cast<const unsigned char**>(frame->extended_data), frame->nb_samples) >= 0,
                        "Audio resampling failed");
                    swr_free(&resampler);
                }
                av_frame_unref(frame);
            }
            require(result == AVERROR(EAGAIN) || result == AVERROR_EOF, "Media decoding failed");
        }
        av_packet_unref(packet);
    }
    int streams = 0;
    for (unsigned i = 0; i < codecs.size(); ++i)
    {
        if (!codecs[i]) continue;
        require(decoded[i] > 0, "Media stream produced no decoded frames");
        ++streams;
        avcodec_free_context(&codecs[i]);
    }
    require(streams > 0, "No playable streams found");
    av_frame_free(&frame);
    av_packet_free(&packet);
    avformat_close_input(&format);
    std::cout << "Decoded and converted " << streams << " stream(s): " << path << '\n';
}

int main(int argc, char** argv)
{
    try
    {
        require(argc >= 2, "Usage: runtime_dependency_checks images <output> <font> | audio | media <file>");
        const std::string mode = argv[1];
        if (mode == "images" && argc == 4) checkImages(argv[2], argv[3]);
        else if (mode == "audio" && argc == 2) checkAudio();
        else if (mode == "media" && argc == 3) checkMedia(argv[2]);
        else throw std::runtime_error("Invalid arguments");
        return 0;
    }
    catch (const std::exception& error)
    {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
