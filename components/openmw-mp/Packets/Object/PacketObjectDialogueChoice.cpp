#include <components/openmw-mp/NetworkMessages.hpp>
#include "PacketObjectDialogueChoice.hpp"

using namespace mwmp;

PacketObjectDialogueChoice::PacketObjectDialogueChoice(RakNet::RakPeerInterface *peer) : ObjectPacket(peer)
{
    packetID = ID_OBJECT_DIALOGUE_CHOICE;
    hasCellData = true;
}

void PacketObjectDialogueChoice::Object(BaseObject& baseObject, bool send)
{
    ObjectPacket::Object(baseObject, send);
    if (!RW(baseObject.dialogueSession, send)) { packetValid = false; return; }
    RW(baseObject.dialogueChoiceType, send);

    if (baseObject.dialogueChoiceType == DialogueChoiceType::TOPIC)
        RW(baseObject.topicId, send, true);

    RW(baseObject.guiId, send);
}
