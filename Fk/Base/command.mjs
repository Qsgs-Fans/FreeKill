// 本文件为各种UI Command汇集，我们从低到高慢慢来

// RootPage: 提供StackView Toast 以及其他与视觉无关
export const PushPage = 'PushPage';
export const PopPage = 'PopPage';
export const ShowToast = 'ShowToast';
export const SetBusyUI = 'SetBusyUI';

// RootPage 基底页面
export const SetServerSettings = "SetServerSettings";
export const BackToStart = "BackToStart";
export const EnterLobby = "EnterLobby";
export const AddTotalGameTime = "AddTotalGameTime";
export const UpdateAvatar = "UpdateAvatar";
export const UpdatePassword = "UpdatePassword";

// 错误信息
export const ErrorMsg = "ErrorMsg";
export const ErrorDlg = "ErrorDlg";

// Base 基本信息，一般为服务器信息
export const ServerDetected = "ServerDetected";
export const GetServerDetail = "GetServerDetail";
export const ServerMessage = "ServerMessage";

// Lobby 服务器内大厅相关
export const UpdateRoomList = "UpdateRoomList";
export const UpdatePlayerNum = "UpdatePlayerNum";
export const EnterRoom = "EnterRoom";

// Package 包加载
export const UpdatePackage = "UpdatePackage";
export const UpdateBusyText = "UpdateBusyText";
export const DownloadComplete = "DownloadComplete";
export const SetDownloadingPackage = "SetDownloadingPackage";
export const PackageDownloadError = "PackageDownloadError";
export const PackageTransferProgress = "PackageTransferProgress";

// RoomPage 房间基底页
export const ChangeRoomPage = "ChangeRoomPage";
export const ResetRoomPage = "ResetRoomPage";
export const BackToRoom = "BackToRoom";
export const IWantToQuitRoom = "IWantToQuitRoom";
export const IWantToSaveRecord = "IWantToSaveRecord";
export const IWantToBookmarkRecord = "IWantToBookmarkRecord";
export const IWantToChat = "IWantToChat";

// Misc
export const Chat = "Chat";

// LunarLTK.Room
export const SetCardFootnote = "SetCardFootnote";
export const SetCardVirtName = "SetCardVirtName";
export const ShowVirtualCard = "ShowVirtualCard";
export const DestroyTableCard = "DestroyTableCard";
export const DestroyTableCardByEvent = "DestroyTableCardByEvent";
export const MaxCard = "MaxCard";
export const AddPlayer = "AddPlayer";
export const RemovePlayer = "RemovePlayer";
export const RoomOwner = "RoomOwner";
export const ReadyChanged = "ReadyChanged";
export const NetStateChanged = "NetStateChanged";
export const PropertyUpdate = "PropertyUpdate";
export const UpdateHandcard = "UpdateHandcard";
export const UpdateCard = "UpdateCard";
export const UpdateSkill = "UpdateSkill";
export const StartGame = "StartGame";
export const ArrangeSeats = "ArrangeSeats";
export const MoveFocus = "MoveFocus";
export const PlayerRunned = "PlayerRunned";
export const AskForGeneral = "AskForGeneral";
export const AskForSkillInvoke = "AskForSkillInvoke";
export const AskForArrangeCards = "AskForArrangeCards";
export const AskForGuanxing = "AskForGuanxing";
export const AskForExchange = "AskForExchange";
export const AskForChoice = "AskForChoice";
export const AskForChoices = "AskForChoices";
export const AskForCardChosen = "AskForCardChosen";
export const AskForCardsChosen = "AskForCardsChosen";
export const AskForPoxi = "AskForPoxi";
export const AskForMoveCardInBoard = "AskForMoveCardInBoard";
export const AskForCardsAndChoice = "AskForCardsAndChoice";
export const MoveCards = "MoveCards";
export const PlayCard = "PlayCard";
export const LoseSkill = "LoseSkill";
export const AddSkill = "AddSkill";
export const PrelightSkill = "PrelightSkill";
export const AskForUseActiveSkill = "AskForUseActiveSkill";
export const CancelRequest = "CancelRequest";
export const GameLog = "GameLog";
export const AskForUseCard = "AskForUseCard";
export const AskForResponseCard = "AskForResponseCard";
export const SetPlayerMark = "SetPlayerMark";
export const SetBanner = "SetBanner";
export const Animate = "Animate";
export const LogEvent = "LogEvent";
export const GameOver = "GameOver";
export const FillAG = "FillAG";
export const AskForAG = "AskForAG";
export const TakeAG = "TakeAG";
export const CloseAG = "CloseAG";
export const CustomDialog = "CustomDialog";
export const MiniGame = "MiniGame";
export const UpdateMiniGame = "UpdateMiniGame";
export const EmptyRequest = "EmptyRequest";
export const UpdateLimitSkill = "UpdateLimitSkill";
export const UpdateDrawPile = "UpdateDrawPile";
export const UpdateRoundNum = "UpdateRoundNum";
export const UpdateGameData = "UpdateGameData";
export const ChangeSelf = "ChangeSelf";
export const UpdateRequestUI = "UpdateRequestUI";
export const GetPlayerHandcards = "GetPlayerHandcards";
export const ReplyToServer = "ReplyToServer";
export const ReplayerDurationSet = "ReplayerDurationSet";
export const ReplayerElapsedChange = "ReplayerElapsedChange";
export const ReplayerSpeedChange = "ReplayerSpeedChange";
export const ChangeSkin = "ChangeSkin";
