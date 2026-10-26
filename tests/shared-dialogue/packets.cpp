#include <components/openmw-mp/Packets/Player/PacketPlayerDialogue.hpp>
#include <components/openmw-mp/NetworkMessages.hpp>
#include <cstdlib>
#include <iostream>

using namespace mwmp;
int checks = 0;
#define CHECK(condition) do { ++checks; if (!(condition)) { \
    std::cerr << "FAIL line " << __LINE__ << ": " #condition << '\n'; std::exit(1); } } while (false)

int main()
{
    dialogue::Message message, target;
    message.action = dialogue::Action::Open;
    message.session = 123456789;
    message.request = 987;
    message.actor.cell = "balmora, caius cosades' house";
    message.actor.refId = "caius cosades";
    message.actor.name = "Caius Cosades";
    message.actor.refNum = 42;
    message.actor.mpNum = 9;
    message.actor.position[0] = -123.5f;
    message.speaker = "Speaker";
    message.status = "Bartering";
    message.choices = {"Yes", "No"};
    message.topics = {"background", "orders", u8"étranger", u8"日本語"};
    dialogue::Entry greeting;
    greeting.text = u8"Full response: é, 日本語, @orders#\nSecond line.";
    greeting.margin = false;
    message.entries.push_back(greeting);
    dialogue::Entry notification;
    notification.text = "Choice: Yes";
    notification.message = true;
    message.entries.push_back(notification);
    PacketPlayerDialogue writer(nullptr), reader(nullptr);
    writer.setGUID(RakNet::RakNetGUID(1));
    RakNet::BitStream stream;
    writer.serialize(&stream, true, message);
    CHECK(writer.isPacketValid());
    stream.IgnoreBytes(BasePacket::headerSize());
    reader.serialize(&stream, false, target);
    CHECK(reader.isPacketValid());
    CHECK(target.session == message.session);
    CHECK(target.request == message.request);
    CHECK(target.actor == message.actor);
    CHECK(target.actor.position[0] == -123.5f);
    CHECK(target.entries.size() == 2);
    CHECK(target.entries[0].text == greeting.text);
    CHECK(!target.entries[0].margin);
    CHECK(target.entries[1].message);
    CHECK(target.choices == message.choices);
    CHECK(target.topics == message.topics);
    CHECK(target.status == message.status);

    // Every truncation of a valid packet must fail, without using partial data.
    for (unsigned int bytes = BasePacket::headerSize(); bytes < stream.GetNumberOfBytesUsed(); ++bytes)
    {
        RakNet::BitStream truncated(stream.GetData(), bytes, false);
        truncated.IgnoreBytes(BasePacket::headerSize());
        reader.serialize(&truncated, false, target);
        CHECK(!reader.isPacketValid());
    }

    RakNet::BitStream malicious;
    malicious.Write(static_cast<unsigned char>(dialogue::Action::Open));
    malicious.Write(std::uint64_t(1));
    malicious.Write(std::uint64_t(1));
    malicious.Write(false);
    malicious.Write(std::uint32_t(0xffffffff)); // first string length: do not allocate
    reader.serialize(&malicious, false, target);
    CHECK(!reader.isPacketValid());
    CHECK(target.actor.cell.empty());

    RakNet::BitStream unknown;
    unknown.Write(static_cast<unsigned char>(255));
    reader.serialize(&unknown, false, target);
    CHECK(!reader.isPacketValid());

    // Topic counts, individual lengths and total bytes are bounded on both paths.
    for (const auto& topics : {
        std::vector<std::string>(dialogue::MaxTopics + 1, "topic"),
        std::vector<std::string>{std::string(dialogue::MaxString + 1, 'x')},
        std::vector<std::string>(dialogue::MaxTopicBytes / dialogue::MaxString + 1,
            std::string(dialogue::MaxString, 'x'))})
    {
        dialogue::Message invalid;
        invalid.topics = topics;
        RakNet::BitStream badTopics;
        writer.serialize(&badTopics, true, invalid);
        CHECK(!writer.isPacketValid());
        badTopics.IgnoreBytes(BasePacket::headerSize());
        reader.serialize(&badTopics, false, target);
        CHECK(!reader.isPacketValid());
    }

    // An updated topic list replaces the previous one, including an empty list.
    for (const auto& topics : {std::vector<std::string>{"newly discovered topic"}, std::vector<std::string>{}})
    {
        dialogue::Message state;
        state.action = dialogue::Action::State;
        state.topics = topics;
        RakNet::BitStream update;
        writer.serialize(&update, true, state);
        CHECK(writer.isPacketValid());
        update.IgnoreBytes(BasePacket::headerSize());
        reader.serialize(&update, false, target);
        CHECK(reader.isPacketValid());
        CHECK(target.topics == topics);
    }

    // Decode a second packet into the same object; old history must not survive.
    message = dialogue::Message();
    message.action = dialogue::Action::End;
    message.session = 999;
    RakNet::BitStream end;
    writer.serialize(&end, true, message);
    end.IgnoreBytes(BasePacket::headerSize());
    reader.serialize(&end, false, target);
    CHECK(reader.isPacketValid());
    CHECK(target.entries.empty());
    CHECK(target.choices.empty());
    CHECK(target.topics.empty());
    CHECK(target.session == 999);
    std::cout << checks << " production packet checks passed\n";
}
