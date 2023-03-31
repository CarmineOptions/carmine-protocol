const PROPOSAL_VOTING_TIME_BLOCKS = 500;
const NEW_PROPOSAL_QUORUM = 200; // 1/200 of totalSupply required to propose an upgrade. Quorums don't take into account investors. at all, they don't count into total eligible voters, but do vote.
const QUORUM = 20; // 1/20 of totalSupply required to participate or pass
const TEAM_TOKEN_BALANCE = 5000000000000000000; // 5 * 10^18. Used only in calculation of investor voting power.


const OPTION_CALL = 0;
const OPTION_PUT = 1;
const TRADE_SIDE_LONG = 0;
const TRADE_SIDE_SHORT = 1;
