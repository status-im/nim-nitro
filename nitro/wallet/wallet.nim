import std/tables
import ../basics
import ../keys
import ../protocol
import ./signedstate
import ./ledger

include questionable/errorban

export basics
export keys
export signedstate

type
  Wallet* = object
    key: PrivateKey
    channels: Table[ChannelId, SignedState]
  ChannelId* = Destination

func init*(_: type Wallet, key: PrivateKey): Wallet =
  result.key = key

func address*(wallet: Wallet): EthAddress =
  wallet.key.toPublicKey.toAddress

func `[]`*(wallet: Wallet, channel: ChannelId): ?SignedState =
  wallet.channels[channel].catch.option

func sign(wallet: Wallet, state: SignedState): SignedState =
  var signed = state
  signed.signatures &= @{wallet.address: wallet.key.sign(state.state)}
  signed

func createChannel(wallet: var Wallet, state: SignedState): ChannelId =
  let signed = wallet.sign(state)
  let id = getChannelId(signed.state.channel)
  wallet.channels[id] = signed
  id

func openLedgerChannel*(wallet: var Wallet,
                        hub: EthAddress,
                        chainId: UInt256,
                        nonce: UInt48,
                        asset: EthAddress,
                        amount: UInt256): ChannelId =
  let state = startLedger(wallet.address, hub, chainId, nonce, asset, amount)
  wallet.createChannel(state)

func acceptChannel*(wallet: var Wallet, signed: SignedState): ?!ChannelId =
  if not signed.hasParticipant(wallet.address):
    return ChannelId.failure "wallet owner is not a participant"

  if not verifySignatures(signed):
    return ChannelId.failure "incorrect signatures"

  wallet.createChannel(signed).success