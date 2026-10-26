#include "SharedDialogue.hpp"
#include "Networking.hpp"
#include "Player.hpp"
#include <components/misc/stringops.hpp>
#include <components/settings/settings.hpp>
#include <components/openmw-mp/NetworkMessages.hpp>

namespace mwmp
{
    namespace
    {
        std::string cellName(const Player& player)
        { return Misc::StringUtils::lowerCase(player.cell.getShortDescription()); }
        Player* findPlayer(std::uint64_t id) { return Players::getPlayer(RakNet::RakNetGUID(id)); }
        bool ready(Player& player)
        { return player.isHandshaked() && player.getLoadState() == Player::POSTLOADED && !player.creatureStats.mDead; }
    }

    SharedDialogue& SharedDialogue::get() { static SharedDialogue instance; return instance; }
    void SharedDialogue::configure()
    {
        // Old server configs remain usable; the new shipped default documents this option.
        try { mRadius = Settings::Manager::getFloat("radius", "Dialogue"); }
        catch (const std::exception&) { mRadius = dialogue::DefaultRadius; }
        if (!std::isfinite(mRadius) || mRadius <= 0) mRadius = dialogue::DefaultRadius;
    }
    void SharedDialogue::send(Player& player, const dialogue::Message& message)
    {
        player.sharedDialogue = message;
        auto* packet = Networking::get().getPlayerPacketController()->GetPacket(ID_PLAYER_DIALOGUE);
        packet->setPlayer(&player); // Address the recipient, even for an unseen speaker.
        packet->Send(false);
    }
    void SharedDialogue::open(Player& player, const dialogue::Session& session, std::uint64_t request)
    {
        dialogue::Message message;
        message.action = dialogue::Action::Open;
        message.request = request;
        message.session = session.id;
        message.owner = session.owner == player.guid.g;
        message.actor = session.actor;
        message.speaker = session.speaker;
        message.entries = session.history;
        message.choices = session.choices;
        message.topics = session.topics;
        message.status = session.status;
        send(player, message);
    }
    void SharedDialogue::broadcast(const dialogue::Session& session, const dialogue::Message& message)
    {
        for (auto id : session.listeners)
            if (auto* listener = findPlayer(id)) send(*listener, message);
    }
    void SharedDialogue::end(std::uint64_t id, const std::string& reason)
    {
        auto* session = mSessions.find(id);
        if (!session) return;
        dialogue::Message message;
        message.action = dialogue::Action::End;
        message.session = id;
        message.status = reason;
        broadcast(*session, message);
        if (auto* owner = findPlayer(session->owner)) send(*owner, message);
        mSessions.end(id, session->owner);
    }
    void SharedDialogue::process(Player& player, const dialogue::Message& message)
    {
        using dialogue::Action;
        if (message.action == Action::Request)
        {
            auto deny = [&]() {
                dialogue::Message denied;
                denied.action = Action::Denied;
                denied.request = message.request;
                denied.status = "Conversation unavailable. Move closer and try again.";
                send(player, denied);
            };
            if (!ready(player) || message.request == 0 || message.actor.refId.empty() ||
                !dialogue::inRange(message.actor, cellName(player), player.position.pos, mRadius))
            { deny(); return; }
            auto* existing = mSessions.forActor(message.actor);
            if (existing && (!dialogue::inRange(existing->actor, cellName(player), player.position.pos, mRadius)
                || existing->owner == player.guid.g)) { deny(); return; }
            auto* session = mSessions.open(player.guid.g, message.actor, player.npc.mName);
            if (!session) { deny(); return; }
            if (existing)
            {
                if (!mSessions.join(session->id, player.guid.g)) { deny(); return; }
                open(player, *session, message.request);
                return;
            }
            open(player, *session, message.request);
            for (auto& pair : *Players::getPlayers())
            {
                auto& other = *pair.second;
                if (other.guid != player.guid && ready(other) && !mSessions.participates(other.guid.g) &&
                    dialogue::inRange(session->actor, cellName(other), other.position.pos, mRadius) &&
                    mSessions.join(session->id, other.guid.g)) open(other, *session, 0);
            }
            return;
        }
        auto* session = mSessions.find(message.session);
        if (!session) return; // Late packets cannot recreate a closed conversation.
        if (message.action == Action::Leave)
        {
            session->listeners.erase(player.guid.g);
            return;
        }
        if (session->owner != player.guid.g) return;
        if (message.action == Action::End) { end(session->id, ""); return; }
        if (!ready(player) || cellName(player) != session->actor.cell)
        { end(session->id, "Conversation ended."); return; }
        if (message.action == Action::Append && message.entries.size() == 1)
        {
            if (!mSessions.append(session->id, player.guid.g, message.entries.front()))
            { end(session->id, "Conversation history limit reached. Please start a new conversation."); return; }
            broadcast(*session, message);
        }
        else if (message.action == Action::State &&
            mSessions.state(session->id, player.guid.g, message.status, message.choices, message.topics))
            broadcast(*session, message);
    }
    void SharedDialogue::update()
    {
        std::vector<std::uint64_t> ended;
        for (const auto& pair : mSessions.all())
        {
            const auto& session = pair.second;
            auto* owner = findPlayer(session.owner);
            if (!owner || !ready(*owner) || cellName(*owner) != session.actor.cell)
            { ended.push_back(session.id); continue; }
            std::vector<std::uint64_t> left;
            for (auto id : session.listeners)
            {
                auto* listener = findPlayer(id);
                if (!listener || !ready(*listener) || cellName(*listener) != session.actor.cell)
                {
                    if (listener)
                    {
                        dialogue::Message message;
                        message.action = dialogue::Action::End;
                        message.session = session.id;
                        send(*listener, message);
                    }
                    left.push_back(id);
                }
            }
            for (auto id : left) mSessions.find(session.id)->listeners.erase(id);
        }
        for (auto id : ended) end(id, "Conversation ended.");
    }
    void SharedDialogue::disconnect(std::uint64_t player)
    {
        std::vector<std::uint64_t> ended;
        for (const auto& pair : mSessions.all())
            if (pair.second.owner == player) ended.push_back(pair.first);
        for (auto id : ended) end(id, "The speaker disconnected.");
        mSessions.leave(player);
    }
    bool SharedDialogue::mayChoose(std::uint64_t player, const dialogue::Actor& actor, std::uint64_t id)
    {
        auto* session = mSessions.forActor(actor);
        return session && session->owner == player && session->id == id;
    }
}
