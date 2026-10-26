#ifndef OPENMW_PROCESSOROBJECTDIALOGUECHOICE_HPP
#define OPENMW_PROCESSOROBJECTDIALOGUECHOICE_HPP

#include "../ObjectProcessor.hpp"
#include <apps/openmw-mp/Networking.hpp>
#include <apps/openmw-mp/SharedDialogue.hpp>
#include <components/misc/stringops.hpp>

namespace mwmp
{
    class ProcessorObjectDialogueChoice : public ObjectProcessor
    {
    public:
        ProcessorObjectDialogueChoice()
        {
            BPP_INIT(ID_OBJECT_DIALOGUE_CHOICE)
        }

        void Do(ObjectPacket &packet, Player &player, BaseObjectList &objectList) override
        {
            // Validate ownership before Lua can forward any executable topic/service.
            for (const auto& object : objectList.baseObjects)
            {
                dialogue::Actor actor;
                actor.cell = Misc::StringUtils::lowerCase(objectList.cell.getShortDescription());
                actor.refId = Misc::StringUtils::lowerCase(object.refId);
                actor.refNum = object.refNum;
                actor.mpNum = object.mpNum;
                if (!packet.isPacketValid() || !SharedDialogue::get().mayChoose(player.guid.g, actor, object.dialogueSession)) return;
            }
            LOG_MESSAGE_SIMPLE(TimedLog::LOG_INFO, "Received %s from %s", strPacketID.c_str(), player.npc.mName.c_str());

            Script::Call<Script::CallbackIdentity("OnObjectDialogueChoice")>(player.getId(), objectList.cell.getShortDescription().c_str());
        }
    };
}

#endif //OPENMW_PROCESSOROBJECTDIALOGUECHOICE_HPP
