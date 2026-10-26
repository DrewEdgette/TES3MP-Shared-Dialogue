#ifndef TES3MP_PACKETPLAYERDIALOGUE_HPP
#define TES3MP_PACKETPLAYERDIALOGUE_HPP

#include "PlayerPacket.hpp"

namespace mwmp
{
    class PacketPlayerDialogue : public PlayerPacket
    {
    public:
        explicit PacketPlayerDialogue(RakNet::RakPeerInterface* peer);
        void Packet(RakNet::BitStream* stream, bool send) override;
        void serialize(RakNet::BitStream* stream, bool send, dialogue::Message& data);
    };
}
#endif
