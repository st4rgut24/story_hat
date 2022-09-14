// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

library SharedStructs {
    struct Author {
        address addr;
        bytes32 username;
        bytes profilePicCID;
        uint8 reputation;
    }

    enum StorylineState {
        OPEN,
        DRAFTING,
        DRAFTING_END,
        FINAL_REVIEW,
        PUBLISHED
    }

    struct Contribution {
        address authorAddr;
        bytes cid;
        bytes prevCID;
        bytes[] nextCIDs;
        uint8 contribCount;
        StorylineState state;
        address leader; // TODO: allow the author to transfer leader status to another contributor
    }

    struct StoryDetails {
        bytes cid;
        string title;
        string summary;
        bytes32 genre;
    }    
}
