module MetaLines exposing
    ( Diff
    , DiffValue
    , MetaLines
    , MetaValue(..)
    , SetFailed(..)
    , allOk
    , applyDiff
    , default
    , getDiff
    , emptyDiff
    , fromList
    , parseAndSet
    , setDiff
    , toDiffList
    , toNonDefaultStringList
    , toStringList
    )


import Dict exposing (Dict)


type MetaValue =
      MvInt Int
    | MvString String


type alias MetaLines =
    Dict String MetaValue


defaultList : List (String, MetaValue)
defaultList =
    [ ("name", MvString "")
    , ("description", MvString "")
    , ("author_name", MvString "")
    , ("author_url", MvString "")
    , ("hint.1", MvString "")
    , ("hint.2", MvString "") -- TODO: expandable lists?
    , ("hint.3", MvString "")
    , ("solution.1", MvString "")
    , ("solution.2", MvString "")
    , ("solution.3", MvString "")
    , ("num_rabbits", MvInt 10)
    , ("num_to_save", MvInt 1)
    , ("rabbit_delay", MvString "4") -- TODO: list of ints
    , ("bash", MvInt 0)
    , ("dig", MvInt 0)
    , ("bridge", MvInt 0)
    , ("block", MvInt 0)
    , ("climb", MvInt 0)
    , ("explode", MvInt 0)
    , ("brolly", MvInt 0)
    ]


default : MetaLines
default =
    Dict.fromList defaultList


fromList : List (String, MetaValue) -> MetaLines
fromList values =
    let
        -- Ignore any bad keys
        checkedSet : (String, MetaValue) -> MetaLines -> MetaLines
        checkedSet (name, value) existing =
            case Dict.get name default of
                Just _ -> Dict.insert name value existing
                Nothing -> Debug.log ("fromList: Bad name! " ++ name) existing
    in
        List.foldl checkedSet default values


listToStringList : List (String, MetaValue) -> List (String, String)
listToStringList metaLines =
    let
        mvToString : (String, MetaValue) -> (String, String)
        mvToString (name, value) =
            let
                v =
                    case value of
                        MvInt i -> toString i
                        MvString s -> s
            in
                (name, v)
    in
        List.map mvToString metaLines


toStringList : MetaLines -> List (String, String)
toStringList metaLines =
    let
        inOrder
            : List (String, MetaValue)
            -> MetaLines
            -> List (String, MetaValue)
        inOrder orderList metaLines =
            case orderList of
                (name, _) :: ts ->
                    case Dict.get name metaLines of
                        Just v -> (name, v) :: inOrder ts metaLines
                        Nothing -> inOrder ts metaLines
                default ->
                    []
    in
        listToStringList (inOrder defaultList metaLines)


toNonDefaultStringList : MetaLines -> List (String, String)
toNonDefaultStringList metaLines =
    let
        nonDefault : String -> MetaValue -> Bool
        nonDefault name value =
            Dict.get name default /= Just value
    in
        listToStringList (Dict.toList (Dict.filter nonDefault metaLines))


type SetFailed =
      UnknownName String
    | BadValue String String


parseAndSet : String -> String -> MetaLines -> Result SetFailed MetaLines
parseAndSet name value metaLines =
    let
        setInt : String -> String -> MetaLines -> Result SetFailed MetaLines
        setInt name value metaLines =
            case String.toInt value of
                Ok i -> Ok (Dict.insert name (MvInt i) metaLines)
                Err _ -> Err (BadValue name value)

        setString : String -> String -> MetaLines -> Result SetFailed MetaLines
        setString name value metaLines =
            Ok (Dict.insert name (MvString value) metaLines)
    in
        case Dict.get name metaLines of
            Just (MvInt _) ->
                setInt name value metaLines
            Just (MvString _) ->
                setString name value metaLines
            default ->
                Err (UnknownName name)


-- Diffs


type alias DiffValue =
    { raw : String
    , parsed : Result SetFailed MetaValue
    }


type alias Diff =
    Dict String DiffValue


emptyDiff : Diff
emptyDiff =
    Dict.empty


setDiff : String -> String -> Diff -> Diff
setDiff name value diff =
    let
        parseInt : String -> String -> Result SetFailed MetaValue
        parseInt name value =
            case String.toInt value of
                Ok i -> Ok (MvInt i)
                Err _ -> Err (BadValue name value)
    in
        case Dict.get name default of  -- Uses default, which feels bad?
            Just (MvString _) ->
                Dict.insert name {raw=value, parsed=Ok (MvString value)} diff
            Just (MvInt _) ->
                Dict.insert name {raw=value, parsed=parseInt name value} diff
            Nothing ->
                Debug.log ("setDiff: unknown name: " ++ name) diff


getDiff : String -> Diff -> Maybe DiffValue
getDiff =
    Dict.get


toDiffList : Diff -> List (String, DiffValue)
toDiffList diff =
    Dict.toList diff


-- Apply the supplied diff, ignoring any bad values
applyDiff : Diff -> MetaLines -> MetaLines
applyDiff diff metaLines =
    let
        setValue : String -> DiffValue -> MetaLines -> MetaLines
        setValue name diffValue metaLines =
            case diffValue.parsed of
                Ok v -> Dict.insert name v metaLines
                Err _ -> metaLines  -- Ignore errors
    in
        Dict.foldl setValue metaLines diff


allOk : Diff -> Bool
allOk diff =
    let
        parsedOk : (String, DiffValue) -> Bool
        parsedOk (_, val) =
            case val.parsed of
                Ok _ -> True
                Err _ -> False
    in
        List.all parsedOk (Dict.toList diff)
