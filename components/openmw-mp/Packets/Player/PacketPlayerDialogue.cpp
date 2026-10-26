#include "PacketPlayerDialogue.hpp"
#include <components/openmw-mp/NetworkMessages.hpp>

namespace mwmp
{
    PacketPlayerDialogue::PacketPlayerDialogue(RakNet::RakPeerInterface* peer) : PlayerPacket(peer)
    {
        packetID = ID_PLAYER_DIALOGUE;
    }

    void PacketPlayerDialogue::Packet(RakNet::BitStream* stream, bool send)
    {
        serialize(stream, send, player->sharedDialogue);
    }

    void PacketPlayerDialogue::serialize(RakNet::BitStream* stream, bool send, dialogue::Message& data)
    {
        PlayerPacket::Packet(stream, send);
        if (!send) data = dialogue::Message();

        // Use length-prefixed, bounded raw bytes: reject bad lengths BEFORE allocating.
        auto string = [&](std::string& value) {
            std::uint32_t size = send ? static_cast<std::uint32_t>(value.size()) : 0;
            if (!RW(size, send) || size > dialogue::MaxString) return false;
            if (!send) value.resize(size);
            if (!size) return true;
            char* bytes = &value[0];
            return RW(bytes, size, send);
        };
        unsigned char action = static_cast<unsigned char>(data.action);
        if (!RW(action, send) || action > static_cast<unsigned char>(dialogue::Action::Denied) ||
            !RW(data.session, send) || !RW(data.request, send) || !RW(data.owner, send) ||
            !string(data.actor.cell) || !string(data.actor.refId) || !string(data.actor.name) ||
            !RW(data.actor.refNum, send) || !RW(data.actor.mpNum, send))
        { packetValid = false; return; }
        data.action = static_cast<dialogue::Action>(action);
        for (auto& coordinate : data.actor.position)
            if (!RW(coordinate, send) || !std::isfinite(coordinate)) { packetValid = false; return; }
        if (!string(data.speaker) || !string(data.status)) { packetValid = false; return; }
        std::uint32_t count = send ? static_cast<std::uint32_t>(data.entries.size()) : 0;
        if (!RW(count, send) || count > dialogue::MaxEntries) { packetValid = false; return; }
        if (!send) data.entries.resize(count);
        std::size_t bytes = 0;
        for (auto& entry : data.entries)
        {
            if (!string(entry.title) || !string(entry.text) || !RW(entry.message, send) || !RW(entry.margin, send))
            { packetValid = false; return; }
            bytes += entry.bytes();
            if (bytes > dialogue::MaxHistoryBytes) { packetValid = false; return; }
        }
        count = send ? static_cast<std::uint32_t>(data.choices.size()) : 0;
        if (!RW(count, send) || count > dialogue::MaxChoices) { packetValid = false; return; }
        if (!send) data.choices.resize(count);
        for (auto& choice : data.choices)
            if (!string(choice)) { packetValid = false; return; }
        count = send ? static_cast<std::uint32_t>(data.topics.size()) : 0;
        if (!RW(count, send) || count > dialogue::MaxTopics) { packetValid = false; return; }
        if (!send) data.topics.resize(count);
        bytes = 0;
        for (auto& topic : data.topics)
        {
            if (!string(topic)) { packetValid = false; return; }
            bytes += topic.size();
            if (bytes > dialogue::MaxTopicBytes) { packetValid = false; return; }
        }
    }
}
