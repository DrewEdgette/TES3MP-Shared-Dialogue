#ifndef TES3MP_SHARED_DIALOGUE_HPP
#define TES3MP_SHARED_DIALOGUE_HPP

#include <cmath>
#include <cstdint>
#include <map>
#include <set>
#include <string>
#include <tuple>
#include <vector>

namespace mwmp { namespace dialogue
{
    // Presentation only: no topic IDs, script source, or executable choices.
    enum class Action : unsigned char { Request, Open, Append, State, Leave, End, Denied };
    constexpr std::size_t MaxString = 32768;
    constexpr std::size_t MaxEntries = 4096;
    constexpr std::size_t MaxHistoryBytes = 4 * 1024 * 1024;
    constexpr std::size_t MaxChoices = 128;
    constexpr std::size_t MaxTopics = 4096;
    constexpr std::size_t MaxTopicBytes = 256 * 1024;
    constexpr float DefaultRadius = 420.f;

    inline bool validTopics(const std::vector<std::string>& topics)
    {
        if (topics.size() > MaxTopics) return false;
        std::size_t bytes = 0;
        for (const auto& topic : topics)
        {
            bytes += topic.size();
            if (topic.size() > MaxString || bytes > MaxTopicBytes) return false;
        }
        return true;
    }

    struct Actor
    {
        std::string cell, refId, name;
        unsigned int refNum = 0, mpNum = 0;
        float position[3] = {};
        bool operator==(const Actor& other) const
        {
            return std::tie(cell, refId, refNum, mpNum) ==
                std::tie(other.cell, other.refId, other.refNum, other.mpNum);
        }
    };

    inline bool inRange(const Actor& actor, const std::string& cell, const float* position, float radius)
    {
        if (actor.cell != cell || !std::isfinite(radius) || radius <= 0) return false;
        double distance = 0;
        for (int i = 0; i < 3; ++i)
        {
            double delta = double(actor.position[i]) - position[i];
            if (!std::isfinite(delta)) return false;
            distance += delta * delta;
        }
        return distance <= double(radius) * radius;
    }

    struct Entry
    {
        std::string title, text;
        bool message = false, margin = true;
        std::size_t bytes() const { return title.size() + text.size(); }
        bool valid() const { return title.size() <= MaxString && text.size() <= MaxString; }
    };

    struct Message
    {
        Action action = Action::Request;
        std::uint64_t session = 0, request = 0;
        bool owner = false;
        Actor actor;
        std::string speaker, status;
        std::vector<Entry> entries;
        std::vector<std::string> choices, topics;
    };

    struct Session
    {
        std::uint64_t id = 0, owner = 0;
        Actor actor;
        std::string speaker, status;
        std::vector<Entry> history;
        std::vector<std::string> choices, topics;
        std::set<std::uint64_t> listeners;
        std::size_t bytes = 0;
    };

    // Single-threaded server authority. Kept independent of the renderer and RakNet
    // so races, ownership, and replay can be tested without Morrowind data files.
    class Sessions
    {
        std::uint64_t mNext = 1;
        std::map<std::uint64_t, Session> mSessions;
    public:
        const std::map<std::uint64_t, Session>& all() const { return mSessions; }
        Session* find(std::uint64_t id)
        {
            auto it = mSessions.find(id);
            return it == mSessions.end() ? nullptr : &it->second;
        }
        Session* forActor(const Actor& actor)
        {
            for (auto& pair : mSessions) if (pair.second.actor == actor) return &pair.second;
            return nullptr;
        }
        bool owns(std::uint64_t player) const
        {
            for (const auto& pair : mSessions) if (pair.second.owner == player) return true;
            return false;
        }
        bool participates(std::uint64_t player) const
        {
            for (const auto& pair : mSessions)
                if (pair.second.owner == player || pair.second.listeners.count(player)) return true;
            return false;
        }
        void leave(std::uint64_t player)
        {
            for (auto& pair : mSessions) pair.second.listeners.erase(player);
        }
        Session* open(std::uint64_t player, const Actor& actor, const std::string& speaker)
        {
            if (auto* active = forActor(actor)) return active;
            if (owns(player)) return nullptr;
            leave(player);
            Session session;
            session.id = mNext++;
            session.owner = player;
            session.actor = actor;
            session.speaker = speaker;
            return &mSessions.emplace(session.id, session).first->second;
        }
        bool join(std::uint64_t id, std::uint64_t player)
        {
            auto* session = find(id);
            if (!session || owns(player)) return false;
            leave(player);
            session->listeners.insert(player);
            return true;
        }
        bool append(std::uint64_t id, std::uint64_t player, const Entry& entry)
        {
            auto* session = find(id);
            if (!session || session->owner != player || !entry.valid() ||
                session->history.size() >= MaxEntries || session->bytes + entry.bytes() > MaxHistoryBytes)
                return false;
            session->history.push_back(entry);
            session->bytes += entry.bytes();
            return true;
        }
        bool state(std::uint64_t id, std::uint64_t player,
            const std::string& status, const std::vector<std::string>& choices,
            const std::vector<std::string>& topics)
        {
            auto* session = find(id);
            if (!session || session->owner != player || status.size() > MaxString || choices.size() > MaxChoices ||
                !validTopics(topics))
                return false;
            for (const auto& choice : choices) if (choice.size() > MaxString) return false;
            session->status = status;
            session->choices = choices;
            session->topics = topics;
            return true;
        }
        bool end(std::uint64_t id, std::uint64_t player)
        {
            auto* session = find(id);
            if (!session || session->owner != player) return false;
            mSessions.erase(id);
            return true;
        }
    };
} }
#endif
