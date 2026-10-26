#ifndef TES3MP_SERVER_SHARED_DIALOGUE_HPP
#define TES3MP_SERVER_SHARED_DIALOGUE_HPP

#include <components/openmw-mp/Dialogue.hpp>
class Player;
namespace mwmp
{
    class SharedDialogue
    {
        dialogue::Sessions mSessions;
        float mRadius = dialogue::DefaultRadius;
        void send(Player& player, const dialogue::Message& message);
        void open(Player& player, const dialogue::Session& session, std::uint64_t request);
        void broadcast(const dialogue::Session& session, const dialogue::Message& message);
        void end(std::uint64_t id, const std::string& reason);
    public:
        static SharedDialogue& get();
        void configure();
        void process(Player& player, const dialogue::Message& message);
        void update();
        void disconnect(std::uint64_t player);
        bool mayChoose(std::uint64_t player, const dialogue::Actor& actor, std::uint64_t session);
    };
}
#endif
