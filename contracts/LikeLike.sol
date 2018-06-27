pragma solidity ^0.4.22;

import "./lib/AddressUtils.sol";
import "./lib/Owned.sol";

contract LikeLike is Owned {
    using AddressUtils for address;

    // 内容（Token）
    struct Item {
        uint256 value; // 价值：收到的总赞赏金额
        uint256 head;
        uint8 ponzi;
        address[] sponsors;
        mapping (address => uint256) remain;
        mapping (address => uint256) total;
    }

    // 用户
    struct User {
        mapping (uint256 => Item) itemMap; // 该用户关联的所有原创内容（Token）
    }

    mapping (address => User) userMap;

    constructor() public {}

    /**
    * 打赏
    *
    * @param {address} _from - 打赏者
    * @param {address} _to - 被打赏者
    * @param {uint256} _item_id - 被打赏者的某项内容编号
    * @param {string} _msg - 打赏附言
    * @param {address} _referrer - 推荐者 （TODO：推荐者可能是多个，应该是个array）
    *
    * msg.sender - 代理商（打赏者可以授权给代理商，让代理商发出打赏，每个代理商是应该是一个合约，合约里可以自定义玩法，比如：打赏抽奖，打赏分红等）
    */
    function like(address _from, address _to, uint256 _item_id, string _msg, address _referrer) public payable {
        address sender = msg.sender;

        require(msg.value > 0); // 打赏金额大于0
        require(_item_id >= 0);
        require(_referrer != _from);
        require(_referrer != _to);
        require(_referrer != sender);
        require(!_referrer.isContract());
        // TODO: 如果 msg.sender != _from(非本人直接打赏), 需要检查msg.sender是否是白名单里的代理商

        User storage user = userMap[_to]; // 被打赏者
        Item storage item = user.itemMap[_item_id]; // 被打赏的内容

        item.sponsors.push(_from);
        item.value += msg.value;

        // 存入尚未兑现的返利
        item.total[_from] += msg.value * item.ponzi / 100;
        item.remain[_from] += msg.value * item.ponzi / 100;

        uint256 msgValue = msg.value * 97 / 100; // 3% cut off for contract

        while(msgValue > 0) {
            // 除了自己之外，没有站岗的人了，把钱分给被打赏者（_to）
            if (item.head + 1 == item.sponsors.length) {
                _to.transfer(msgValue);
                // TODO: emit 事件
                break;
            }

            //  把钱分给站岗者们
            address _sponsor = item.sponsors[item.head];
            if (msgValue <= item.remain[_sponsor]) {
                item.remain[_sponsor] -= msgValue;
                _sponsor.transfer(msgValue);
                // TODO: emit 事件
                break;
            } else {
                msgValue -= item.remain[_sponsor];
                _sponsor.transfer(item.remain[_sponsor]);
                // TODO: emit 事件
                item.remain[_sponsor] = 0;
                item.head++;
            }
        }
        // TODO: call 代理商msg.sender，告知打赏结果
    }

    function setPonzi(uint8 _ponzi, uint256 _item_id) public  {
        require(_ponzi > 0);
        Item storage item = userMap[msg.sender].itemMap[_item_id];
        item.ponzi = _ponzi;
    }
}
