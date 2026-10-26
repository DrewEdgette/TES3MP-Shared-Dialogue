#include "dialogue.hpp"
#include <MyGUI_Button.h>
#include <components/widgets/list.hpp>
#include <components/misc/stringops.hpp>
#include "../mwbase/environment.hpp"
#include "../mwbase/windowmanager.hpp"
#include "../mwbase/world.hpp"
#include "../mwbase/dialoguemanager.hpp"
#include "../mwworld/class.hpp"
#include "../mwworld/cellstore.hpp"
#include "../mwmechanics/actorutil.hpp"
#include "../mwmechanics/creaturestats.hpp"
#include "../mwmp/Main.hpp"
#include "../mwmp/Networking.hpp"
#include "../mwmp/LocalPlayer.hpp"

namespace MWGui
{
    namespace
    {
        void sendShared(const mwmp::dialogue::Message& message)
        {
            auto* network = mwmp::Main::get().getNetworking();
            if (!network->isConnected()) return;
            auto* player = mwmp::Main::get().getLocalPlayer();
            player->sharedDialogue = message;
            auto* packet = network->getPlayerPacket(ID_PLAYER_DIALOGUE);
            packet->setPlayer(player);
            packet->Send();
        }
        std::string cellName(const MWWorld::Ptr& actor)
        { return Misc::StringUtils::lowerCase(actor.getCell()->getCell()->getShortDescription()); }
    }

    void DialogueWindow::clearSharedHistory()
    {
        for (auto* entry : mHistoryContents) delete entry;
        mHistoryContents.clear();
        for (auto* link : mLinks) mDeleteLater.push_back(link);
        mLinks.clear();
        for (const auto& pair : mTopicLinks) mDeleteLater.push_back(pair.second);
        mTopicLinks.clear();
        mKeywordSearch.clear();
        mKeywords.clear();
        mChoices.clear();
    }

    bool DialogueWindow::beginSharedDialogue(const MWWorld::Ptr& actor)
    {
        if (mOpeningShared || !mwmp::Main::get().getNetworking()->isConnected()) return false;
        if ((mSharedSession || mWaitingForShared) && mPtr == actor) return true;
        finishSharedDialogue();
        clearSharedHistory();
        mPtr = actor;
        mSpectator = true; // A pending request must be just as inert as a spectator.
        mWaitingForShared = true;
        mSharedWaitTime = 0;
        mSharedCell = cellName(actor);
        mSharedChoices.clear();
        mSharedTopics.clear();
        mSharedStatus = "Waiting for conversation...";
        mSharedSpeaker.clear();
        mGoodbyeButton->setCaption("Leave");
        mGoodbye = false;
        setTitle(actor.getClass().getName(actor));
        updateTopicsPane();
        updateHistory();
        mwmp::dialogue::Message message;
        message.action = mwmp::dialogue::Action::Request;
        message.request = ++mSharedRequest;
        message.actor.cell = mSharedCell;
        message.actor.refId = Misc::StringUtils::lowerCase(actor.getCellRef().getRefId());
        message.actor.refNum = actor.getCellRef().getRefNum().mIndex;
        message.actor.mpNum = actor.getCellRef().getMpNum();
        message.actor.name = actor.getClass().getName(actor);
        for (int i = 0; i < 3; ++i) message.actor.position[i] = actor.getRefData().getPosition().pos[i];
        sendShared(message);
        return true;
    }

    void DialogueWindow::finishSharedDialogue(bool notifyServer)
    {
        if (mSharedSession && notifyServer)
        {
            mwmp::dialogue::Message message;
            message.action = mSpectator ? mwmp::dialogue::Action::Leave : mwmp::dialogue::Action::End;
            message.session = mSharedSession;
            sendShared(message);
        }
        mSharedSession = 0;
        mWaitingForShared = false;
        mSharedChoices.clear();
        mSharedTopics.clear();
        mSharedStatus.clear();
    }

    void DialogueWindow::shareEntry(const mwmp::dialogue::Entry& entry)
    {
        if (!isSharedDialogueOwner()) return;
        if (!entry.valid())
        {
            closeSharedDialogue(true);
            return;
        }
        mwmp::dialogue::Message message;
        message.action = mwmp::dialogue::Action::Append;
        message.session = mSharedSession;
        message.entries.push_back(entry);
        sendShared(message);
    }

    void DialogueWindow::closeSharedDialogue(bool notifyServer)
    {
        const bool owner = isSharedDialogueOwner();
        auto* windows = MWBase::Environment::get().getWindowManager();
        finishSharedDialogue(notifyServer);
        // Never call goodbyeSelected for a spectator: it changes NPC disposition.
        if (owner && !mPtr.isEmpty()) MWBase::Environment::get().getDialogueManager()->goodbyeSelected();
        mPersuasionDialog.setVisible(false);
        if (owner)
            for (auto mode : {GM_Barter, GM_SpellBuying, GM_Travel, GM_SpellCreation, GM_Enchanting,
                GM_Training, GM_MerchantRepair, GM_Companion}) windows->removeGuiMode(mode);
        windows->removeGuiMode(GM_Dialogue);
        resetReference();
    }

    void DialogueWindow::receiveSharedDialogue(const mwmp::dialogue::Message& message)
    {
        using mwmp::dialogue::Action;
        auto* windows = MWBase::Environment::get().getWindowManager();
        if (message.action == Action::Open)
        {
            auto decline = [&]() {
                mwmp::dialogue::Message reply;
                reply.action = message.owner ? Action::End : Action::Leave;
                reply.session = message.session;
                sendShared(reply);
            };
            if (message.request != 0)
            {
                if (!mWaitingForShared || message.request != mSharedRequest) { decline(); return; }
            }
            else if (mSharedSession || mWaitingForShared || windows->isGuiMode() ||
                !mwmp::Main::get().getLocalPlayer()->isLoggedIn()) { decline(); return; }

            auto* world = MWBase::Environment::get().getWorld();
            auto actor = world->searchPtrViaUniqueIndex(message.actor.refNum, message.actor.mpNum);
            auto player = MWMechanics::getPlayer();
            if (actor.isEmpty() || !actor.getClass().isActor() ||
                Misc::StringUtils::lowerCase(actor.getCellRef().getRefId()) != message.actor.refId ||
                cellName(actor) != message.actor.cell || cellName(player) != message.actor.cell ||
                actor.getClass().getCreatureStats(actor).isDead() || player.getClass().getCreatureStats(player).isDead())
            { decline(); if (mWaitingForShared) windows->removeGuiMode(GM_Dialogue); return; }

            clearSharedHistory();
            mWaitingForShared = false;
            mSharedSession = message.session;
            mSpectator = !message.owner;
            mGoodbyeButton->setCaptionWithReplacing(mSpectator ? "Leave" : "#{sGoodbye}");
            mSharedCell = message.actor.cell;
            mSharedSpeaker = message.speaker;
            mSharedStatus = message.status;
            mSharedChoices = message.choices;
            mSharedTopics = message.topics;
            mOpeningShared = true;
            windows->pushGuiMode(GM_Dialogue, actor);
            mOpeningShared = false;
            if (mSpectator)
            {
                for (const auto& entry : message.entries)
                    mHistoryContents.push_back(entry.message ? static_cast<DialogueText*>(new Message(entry.text)) :
                        new Response(entry.text, entry.title, entry.margin, false));
                updateHistory();
            }
            return;
        }
        if (message.action == Action::Denied)
        {
            if (mWaitingForShared && message.request == mSharedRequest)
            {
                finishSharedDialogue(false);
                windows->removeGuiMode(GM_Dialogue);
                windows->messageBox(message.status);
            }
            return;
        }
        if (!mSharedSession || message.session != mSharedSession) return;
        if (message.action == Action::End)
        {
            closeSharedDialogue(false);
            if (!message.status.empty()) windows->messageBox(message.status);
        }
        else if (mSpectator && message.action == Action::Append)
        {
            for (const auto& entry : message.entries)
                mHistoryContents.push_back(entry.message ? static_cast<DialogueText*>(new Message(entry.text)) :
                    new Response(entry.text, entry.title, entry.margin, false));
            updateHistory();
        }
        else if (mSpectator && message.action == Action::State)
        {
            mSharedChoices = message.choices;
            mSharedTopics = message.topics;
            mSharedStatus = message.status;
            updateTopicsPane();
            updateHistory();
        }
    }

    // Called even while the regular dialogue window is hidden behind a service.
    void DialogueWindow::updateSharedDialogue(float dt)
    {
        if (!mSharedSession && !mWaitingForShared) return;
        auto* windows = MWBase::Environment::get().getWindowManager();
        if (!mwmp::Main::get().getNetworking()->isConnected())
        { closeSharedDialogue(false); return; }
        auto player = MWMechanics::getPlayer();
        if (mPtr.isEmpty() || mPtr.getRefData().getCount() == 0 || cellName(player) != mSharedCell ||
            cellName(mPtr) != mSharedCell || mPtr.getClass().getCreatureStats(mPtr).isDead() ||
            player.getClass().getCreatureStats(player).isDead() || !windows->containsMode(GM_Dialogue))
        { closeSharedDialogue(true); return; }
        if (mWaitingForShared)
        {
            mSharedWaitTime += dt;
            if (mSharedWaitTime > 15.f)
            {
                finishSharedDialogue();
                windows->removeGuiMode(GM_Dialogue);
                windows->messageBox("The server did not open the conversation. Please try again.");
            }
            return;
        }
        if (mSpectator) return;
        std::string status = "Talking";
        switch (windows->getMode())
        {
            case GM_Barter: status = "Bartering"; break;
            case GM_SpellBuying: status = "Buying spells"; break;
            case GM_Travel: status = "Arranging travel"; break;
            case GM_SpellCreation: status = "Creating a spell"; break;
            case GM_Enchanting: status = "Enchanting"; break;
            case GM_Training: status = "Training"; break;
            case GM_MerchantRepair: status = "Repairing equipment"; break;
            case GM_Companion: status = "Sharing equipment"; break;
            default: break;
        }
        if (mPersuasionDialog.isVisible()) status = "Persuading";
        std::vector<std::string> choices;
        for (const auto& choice : MWBase::Environment::get().getDialogueManager()->getChoices())
            choices.push_back(choice.first);
        if (MWBase::Environment::get().getDialogueManager()->isGoodbye()) choices.push_back("Goodbye");
        const std::vector<std::string> topics(mKeywords.begin(), mKeywords.end());
        if (status == mSharedStatus && choices == mSharedChoices && topics == mSharedTopics) return;
        mSharedStatus = status;
        mSharedChoices = choices;
        mSharedTopics = topics;
        mwmp::dialogue::Message message;
        message.action = mwmp::dialogue::Action::State;
        message.session = mSharedSession;
        message.status = status;
        message.choices = choices;
        message.topics = topics;
        sendShared(message);
    }
}
