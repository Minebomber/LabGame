// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface TestVRFConsumerBaseV2 {
	function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}

contract TestVRFCoordinatorV2  {

	struct Request {
		address sender;
		uint32 numWords;
	}
	Request[] requests;

	constructor() {}

  function addConsumer(uint64 subId, address consumer) external {}
	
	function requestRandomWords(
    bytes32,
    uint64,
    uint16,
    uint32,
    uint32 numWords
  ) external returns (uint256 requestId) {
		requests.push(Request(
			msg.sender,
			numWords
		));
		return requests.length - 1;
	}

	function fulfillRequests() external {
		for (uint256 i = 0; i < requests.length; i++) {
			Request memory req = requests[i];
			uint256[] memory words = new uint256[](req.numWords);
			for (uint32 j; j < req.numWords; j++)
				words[j] = random((i << 32) | uint256(j));
			TestVRFConsumerBaseV2(req.sender).rawFulfillRandomWords(i, words);
		}
		while (requests.length > 0)
			requests.pop();
	}

	function random(uint256 seed) internal view returns (uint256) {
		return uint256(keccak256(abi.encodePacked(
			tx.origin,
			blockhash(block.number - 1),
			block.timestamp,
			seed
		)));
	}
}