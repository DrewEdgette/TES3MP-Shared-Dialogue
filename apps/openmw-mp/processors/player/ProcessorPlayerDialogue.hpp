#ifndef TES3MP_SERVER_PROCESSORPLAYERDIALOGUE_HPP
#define TES3MP_SERVER_PROCESSORPLAYERDIALOGUE_HPP
#include "../PlayerProcessor.hpp"
#include "../../SharedDialogue.hpp"
namespace mwmp
{
    class ProcessorPlayerDialogue : public PlayerProcessor
    {
    public:
        ProcessorPlayerDialogue() { BPP_INIT(ID_PLAYER_DIALOGUE) }
        void Do(PlayerPacket& packet, Player& player) override
        {
            if (packet.isPacketValid())
            {
                // Sending a reply reuses BasePlayer storage, so retain the request.
                const auto message = player.sharedDialogue;
                SharedDialogue::get().process(player, message);
            }
        }
    };
}
#endif
