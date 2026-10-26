cmake_minimum_required(VERSION 3.16)
project(shared_dialogue_tests LANGUAGES CXX)
enable_testing()
add_executable(shared_dialogue_tests sessions.cpp)
target_compile_features(shared_dialogue_tests PRIVATE cxx_std_17)
if(MSVC)
    target_compile_options(shared_dialogue_tests PRIVATE /utf-8)
endif()
target_include_directories(shared_dialogue_tests PRIVATE ../..)
add_test(NAME shared_dialogue_sessions COMMAND shared_dialogue_tests)

# Optional wire-format tests compile the actual production packet implementation.
if(DIALOGUE_DEPS)
    add_executable(shared_dialogue_packet_tests packets.cpp
        ../../components/openmw-mp/Packets/BasePacket.cpp
        ../../components/openmw-mp/Packets/Player/PlayerPacket.cpp
        ../../components/openmw-mp/Packets/Player/PacketPlayerDialogue.cpp)
    target_compile_features(shared_dialogue_packet_tests PRIVATE cxx_std_17)
    if(MSVC)
        target_compile_options(shared_dialogue_packet_tests PRIVATE /Gy /utf-8)
        target_link_options(shared_dialogue_packet_tests PRIVATE /OPT:REF)
    endif()
    target_compile_definitions(shared_dialogue_packet_tests PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
    target_include_directories(shared_dialogue_packet_tests PRIVATE ../..
        "${DIALOGUE_DEPS}/CrabNet/include/raknet"
        "${DIALOGUE_DEPS}/built/include"
        "${DIALOGUE_DEPS}/boost-prebuilt/app")
    target_link_libraries(shared_dialogue_packet_tests PRIVATE
        "${DIALOGUE_DEPS}/CrabNet/build/lib/Release/RakNetLibStatic.lib" ws2_32)
    add_test(NAME shared_dialogue_packets COMMAND shared_dialogue_packet_tests)

    add_executable(shared_dialogue_network_tests network.cpp
        ../../components/openmw-mp/Packets/BasePacket.cpp
        ../../components/openmw-mp/Packets/Player/PlayerPacket.cpp
        ../../components/openmw-mp/Packets/Player/PacketPlayerDialogue.cpp)
    target_compile_features(shared_dialogue_network_tests PRIVATE cxx_std_17)
    if(MSVC)
        target_compile_options(shared_dialogue_network_tests PRIVATE /utf-8)
    endif()
    target_compile_definitions(shared_dialogue_network_tests PRIVATE NOMINMAX _CRT_SECURE_NO_WARNINGS)
    target_include_directories(shared_dialogue_network_tests PRIVATE ../..
        "${DIALOGUE_DEPS}/CrabNet/include/raknet"
        "${DIALOGUE_DEPS}/built/include"
        "${DIALOGUE_DEPS}/boost-prebuilt/app")
    target_link_libraries(shared_dialogue_network_tests PRIVATE
        "${DIALOGUE_DEPS}/CrabNet/build/lib/Release/RakNetLibStatic.lib" ws2_32)
endif()
