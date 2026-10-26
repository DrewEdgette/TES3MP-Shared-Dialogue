#ifndef TES3MP_CLIENT_PROCESSORPLAYERDIALOGUE_HPP
#define TES3MP_CLIENT_PROCESSORPLAYERDIALOGUE_HPP
#include "../PlayerProcessor.hpp"
#include "../../../mwbase/environment.hpp"
#include "../../../mwbase/windowmanager.hpp"
#include "../../../mwgui/dialogue.hpp"
namespace mwmp
{
    class ProcessorPlayerDialogue : public PlayerProcessor
    {
    public:
        ProcessorPlayerDialogue() { BPP_INIT(ID_PLAYER_DIALOGUE) }
        void Do(PlayerPacket& packet, BasePlayer* player) override
        {
            if (!isRequest() && player && player == Main::get().getLocalPlayer() && packet.isPacketValid())
            {
                const auto message = player->sharedDialogue;
                MWBase::Environment::get().getWindowManager()->getDialogueWindow()->receiveSharedDialogue(message);
            }
        }
    };
}
#endif
