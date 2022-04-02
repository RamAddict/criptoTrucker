pragma solidity >=0.4.22 <0.9.0;

contract EthTrucker {

uint256 constant TOTAL_PARCELS = 4096;
uint256 constant TOTAL_TRUCKERS = 4096;
uint8 constant MAX_ENTRIES = 20;

enum parcelStatus{ CREATED, ACCEPTED, IN_TRANSPORT, DELIVERED }

struct History {
    uint256 time;
    parcelStatus _event;
}

struct Parcel {
    address payable recipient;
    string destinaion_address;
    address payable sender;
    uint256 bounty;
    address payable current_parcel_holder;
    address payable owner;
    bool    fulfilled;
    parcelStatus most_recent_event;
    uint256[] history_index;
    address payable[] route;
}

Parcel[] public parcels;
address[] public truckers;
History[] public global_history;

constructor () {

}

    function addTrucker() external returns (uint256) {
        truckers.push(msg.sender);
        return truckers.length-1;
    }

    function addParcel(address payable recipient, string memory addr) public payable returns (uint256) {
        require(msg.value > 1e15, "Not paying minimum price to add parcel, you want it for free?!"); // 0.001 eth
        parcels.push(Parcel(recipient, addr, payable(msg.sender), msg.value, payable(msg.sender), payable(msg.sender), false, parcelStatus.CREATED, new uint256[](MAX_ENTRIES), new address payable[](MAX_ENTRIES)));
        return (parcels.length-1);
    }

    function acceptParcel(uint256 index) external {
        require(index >= 0, "invalid parcel index in list low");
        require(index < parcels.length, "invalid parcel index in list high");
        bool isRegistered = false;
        for (uint256 i = 0; i < truckers.length; i++) {
            if (msg.sender == truckers[i]) {
                isRegistered = true;
            }
        }
        require(isRegistered == true, "trucker not registered, do that first");
        // parcels[index].current_parcel_holder = payable(msg.sender);
        parcels[index].most_recent_event = parcelStatus.ACCEPTED;
        global_history.push(History(block.timestamp, parcelStatus.ACCEPTED));
        parcels[index].history_index.push(global_history.length);
    }


    function transferParcel(uint256 index, address payable transferee) external {
        require(index >= 0, "invalid parcel index in list low");
        require(index < parcels.length, "invalid parcel index in list high");
        require(parcels[index].fulfilled == false, "package already fulfilled"); // only if the package isn't already fulfilled
        require(parcels[index].current_parcel_holder == msg.sender, "only who has the package may transfer, holder != msg.sender"); // only who has the package may transfer 
        require(parcels[index].most_recent_event != parcelStatus.DELIVERED,  "parcel is delivered, this parcel must be either accepted or in transit"); // only if it is not delivered
        require(parcels[index].most_recent_event != parcelStatus.CREATED,  "parcel is created, this parcel must be either accepted or in transit"); // only if it not created
        

        parcels[index].current_parcel_holder = transferee;
        global_history.push(History(block.timestamp, parcelStatus.IN_TRANSPORT));
        parcels[index].history_index.push(global_history.length);
        parcels[index].route.push(parcels[index].current_parcel_holder);
        
        if (parcels[index].most_recent_event == parcelStatus.ACCEPTED) {
            parcels[index].most_recent_event = parcelStatus.IN_TRANSPORT;
            parcels[index].current_parcel_holder.transfer(parcels[index].bounty/2); // pay half up front
        }
    }

    
    function deliverParcel(uint256 index) external payable {
        require(index >= 0, "invalid parcel index in list low");
        require(index < parcels.length, "invalid parcel index in list high");
        require(parcels[index].fulfilled == false, "package already fulfilled"); // only if the package isn't already fulfilled
        require(parcels[index].current_parcel_holder == msg.sender, "only who has the package may transfer, holder != msg.sender"); // only who has the package may transfer 
        require(parcels[index].most_recent_event == parcelStatus.IN_TRANSPORT,  "only if parcel is in transit"); // only if it is in transit
        
        parcels[index].fulfilled = true;
        parcels[index].most_recent_event = parcelStatus.DELIVERED;
        parcels[index].current_parcel_holder = parcels[index].recipient;
        global_history.push(History(block.timestamp, parcelStatus.DELIVERED));
        parcels[index].history_index.push(global_history.length);
        parcels[index].route.push(parcels[index].current_parcel_holder);
        payable(msg.sender).transfer(parcels[index].bounty/2); // pay the other half as it arrives
    }


    // TODO: CHECK
    function trackParcel(uint256 index) view external returns (History memory) {
        uint256 hist_length = parcels[index].history_index.length -1;
        return global_history[parcels[index].history_index[hist_length]];
    }
    // TODO: CHECK
    function get_truckers() view public returns (address[] memory) {
        return truckers;
    }

    function get_parcel_at(uint256 index) view public returns (Parcel memory) {
        return parcels[index];
    }
    function get_parcels() view public returns (Parcel[] memory) {
        return parcels;
    }
    function get_global_history_at(uint256 index) view public returns (History memory) {
        return global_history[index];
    }
    function get_global_history() view public returns (History[] memory) {
        return global_history;
    }
    function get_parcel_history_at(uint256 parcel_idx, uint256 history_idx) view public returns (History memory) {
        return global_history[parcels[parcel_idx].history_index[history_idx]];
    }
    function get_parcel_history(uint256 parcel_idx) view public returns (History[] memory) {
        uint256[] memory parcel_hist_idx  = parcels[parcel_idx].history_index;
        History[] memory parcel_hist = new History[](parcel_hist_idx.length);
        for (uint256 i = 0; i < parcel_hist_idx.length; i++) {
            parcel_hist[i] = global_history[parcel_hist_idx[i]];
        }
        return parcel_hist;
    }
}