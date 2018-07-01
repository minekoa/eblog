import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Request)
import Json.Decode as Decode
import Json.Encode as Encode
import Markdown

import TextEditor
import TextEditor.KeyBind
import TextEditor.Buffer
import TextEditor.Option

main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

------------------------------------------------------------
-- MODEL
------------------------------------------------------------

type Page
    = TopPage
    | EntryListPage
    | ViewEntryPage
    | EditEntryPage
    | EditNewEntryPage

type alias EntryInfo =
    { id : String
    , title : String
    }

type alias Entry =
    { id : String
    , title : String
    , content : String
    }

type alias Model =
    { page : Page
    , entry_list : List EntryInfo
    , current_entry : Maybe Entry
    , message : Maybe String
    , editor : TextEditor.Model
    }


init : (Model, Cmd Msg)
init =
    let
        ( m, c ) =
            TextEditor.init
                "editor-id1"
                (TextEditor.KeyBind.basic ++ TextEditor.KeyBind.gates ++ TextEditor.KeyBind.emacsLike)
                ""
        opt = TextEditor.options m

    in
        ( { page = TopPage
          , entry_list = []
          , current_entry = Nothing
          , message = Nothing
          , editor = m |> TextEditor.setOptions { opt | showControlCharactor = True }
          }
        , Cmd.map EditorMsg c
        )

brank_entry : Entry
brank_entry =
    { id = ""
    , title= "(*無題*)"
    , content=""
    }

------------------------------------------------------------
-- UPDATE
------------------------------------------------------------

type Msg
    = RequestEntryList
    | ShowEntryList (Result Http.Error (List EntryInfo))
    | RequestEntry String
    | ShowEntry (Result Http.Error Entry)
    | EditEntry
    | SaveEntry
    | SaveEntryComplete String (Result Http.Error String)
    | DeleteEntry String
    | DeleteEntryComplete String (Result Http.Error String)
    | EditNewEntry 
    | SaveNewEntry 
    | SaveNewEntryComplete (Result Http.Error String)
    | EditorMsg TextEditor.Msg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        RequestEntryList ->
            ( {model | message = Nothing}
            , requestEntryList )

        ShowEntryList (Ok entry_list) ->
            ( { model | page = EntryListPage
                      , entry_list = entry_list
                      , current_entry = Nothing }
            , Cmd.none )

        ShowEntryList (Err _) ->
            ( { model | message = Just("エントリー一覧を取得できませんでした") }
            , Cmd.none)

        RequestEntry id ->
            ( {model | message = Nothing}
            , requestEntry id )

        ShowEntry (Ok entry) ->
            ( {model | page = ViewEntryPage
                     , current_entry = Just entry }
            , Cmd.none)

        ShowEntry (Err _) ->
            ( {model | message = Just("エントリーを取得できませんでした") }
            , Cmd.none)

        EditEntry ->
            case model.current_entry of
                Just(entry) ->
                    (  {model
                           | page = EditEntryPage
                           , message = Nothing
                           , editor = TextEditor.setBuffer
                                          ( TextEditor.Buffer.init
                                                (model.current_entry |> Maybe.andThen (\e -> Just e.content) |> Maybe.withDefault "")
                                          )
                                          model.editor
                            
                       }
                    , Cmd.none)
                Nothing ->
                    ( model, Cmd.none)

        SaveEntry ->
            case model.current_entry of
                Just(entry) ->
                    ( model
                    , uploadEntry entry)
                Nothing ->
                    ( model, Cmd.none)

        SaveEntryComplete id (Ok _) ->
            ( model
            , requestEntry id )

        SaveEntryComplete id (Err _) ->
            ( {model | message = Just("エントリー" ++ id ++ "の保存に失敗しました") }
            , Cmd.none)

        DeleteEntry id ->
            ( model
            , deleteEntry id)

        DeleteEntryComplete id (Ok _) ->
            ( model
            , requestEntryList )

        DeleteEntryComplete id (Err _) ->
            ( {model | message = Just("エントリー" ++ id ++ "の削除に失敗しました") }
            , Cmd.none)

        EditNewEntry ->
            ( {model
                  | current_entry = Just brank_entry
                  , page = EditNewEntryPage
                  , message = Nothing
                  , editor = TextEditor.setBuffer (TextEditor.Buffer.init"") model.editor
              }
            , Cmd.none)

        SaveNewEntry  ->
            case model.current_entry of
                Just(entry) ->
                    ( model
                    , uploadNewEntry entry)
                Nothing ->
                    ( model, Cmd.none)

        SaveNewEntryComplete (Ok _) ->
            ( model
            , requestEntryList )

        SaveNewEntryComplete (Err _) ->
            ( {model | message = Just("あたらしいエントリーの保存に失敗しました") }
            , Cmd.none)

        EditorMsg edmsg ->
            let
                ( m, c ) =
                    TextEditor.update edmsg model.editor
            in
                ( case (model.current_entry, edmsg) of
                      (Just entry, TextEditor.UpdateContents new_contents) ->
                          { model
                              | current_entry = Just {entry | content = String.join "\n" new_contents}
                              , editor = m
                          }

                      _ ->
                          { model | editor = m }
                , Cmd.map EditorMsg c
                )


------------------------------------------------------------
-- VIEW
------------------------------------------------------------

view : Model -> Html Msg
view model = div [class "root_box"]
             [ h1 [class "site-title"] [text "EE Blog (Erlang×Elm)"]
             , navibar model.page
             , messageLine model.message
             , case model.page of
                   TopPage          -> topPage model
                   EntryListPage    -> entryListPage model.entry_list
                   ViewEntryPage    -> viewEntryPage model.current_entry
                   EditEntryPage    -> editEntryPage model.current_entry model.editor
                   EditNewEntryPage -> editNewEntryPage model.current_entry model.editor
             ]

navibar : Page -> Html Msg
navibar page =
    div [class "navibar"]
        [ span [class "navitem", onClick RequestEntryList] [text "一覧"]
        , span [class "navitem", onClick EditEntry] [text "編集"]
        , span [class "navitem", onClick EditNewEntry] [text "新規作成"]
        ]

messageLine : Maybe String -> Html Msg
messageLine maybe_message =
     case maybe_message of
         Just(message) ->
             div [class "messageline"] [text message]
         Nothing  ->
             text ""

topPage : Model -> Html Msg
topPage model =
    text "ようこそ! まずは [一覧] をクリックしてください"

entryListPage : List EntryInfo -> Html Msg
entryListPage entry_list =
    div [class "page_box"]
        [ table [] (List.map (λx -> tr [] [ td [class "id_col"]    [span [onClick (RequestEntry x.id)][text x.id]]
                                          , td [class "title_col"] [span [onClick (RequestEntry x.id)][text x.title]]
                                          ]
                             ) (List.sortBy .id entry_list) |> List.reverse
                   )
        ]

viewEntryPage : Maybe Entry -> Html Msg
viewEntryPage mb_entry =
    case mb_entry of
        Just( entry ) ->
            div [class "page_box"]
                [ span [] [text entry.id]
                , Markdown.toHtmlWith markdownOptions [class "md"] entry.content
                ]
        Nothing ->
            div [class "page_box"][text "ページがありません"]

editEntryPage : Maybe Entry -> TextEditor.Model -> Html Msg
editEntryPage mb_entry editor =
    case mb_entry of
        Just( entry ) ->
            div [class "page_box"]
                [ div [] [ span [class "editer_action", onClick SaveEntry] [text "保存"]
                         , span [class "editer_action", onClick (RequestEntry entry.id)] [text "キャンセル"]
                         , span [class "editer_action", onClick (DeleteEntry entry.id)] [text "削除"]
                         ]
                , h1 [] [text ("(" ++ entry.id ++ " を編集中)")]
                , div [class "editor_box"][ div [class "editarea"]    [ Html.map EditorMsg (TextEditor.view editor) ] --[ textarea [onInput EditContent] [text entry.content] ]
                                          , div [class "previewarea"] [ Markdown.toHtmlWith markdownOptions [class "md"] entry.content ]
                                          ]
                ]
        Nothing ->
            div [class "page_box"][text "ページがありません"]

editNewEntryPage : Maybe Entry -> TextEditor.Model -> Html Msg
editNewEntryPage mb_entry editor =
    case mb_entry of
        Just( entry ) ->
            div [class "page_box"]
                [ div [] [ span [class "editer_action", onClick SaveNewEntry] [text "保存"]
                         , span [class "editer_action", onClick (RequestEntryList)] [text "キャンセル"]
                         ]
                , h1 [] [text "(新しいエントリーを編集中)"]
                , div [class "editor_box"] [ div [class "editarea"]    [ Html.map EditorMsg (TextEditor.view editor) ] --[ textarea [onInput EditContent] [text entry.content] ]
                                           , div [class "previewarea"] [ Markdown.toHtmlWith markdownOptions [class "md"] entry.content ]
                                           ]
                ]
        Nothing ->
            div [class "page_box"][text "ページがありません"]

------------------------------------------------------------
-- SUBSCRIPTIONS
------------------------------------------------------------

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map EditorMsg (TextEditor.subscriptions model.editor)

------------------------------------------------------------
-- OTHERS
------------------------------------------------------------

-- REST REQUEST

requestEntryList : Cmd Msg
requestEntryList =
    let
        url = "v1/entries"
    in
        Http.send ShowEntryList (Http.get url entryListDecoder)


requestEntry : String -> Cmd Msg
requestEntry id =
    let
        url = "v1/entries/" ++ id
    in
        Http.send ShowEntry (Http.get url entryDecoder)


uploadEntry : Entry -> Cmd Msg
uploadEntry entry =
    let
        url = "v1/entries/" ++ entry.id
        json = Http.jsonBody( Encode.object [ ("id", Encode.string entry.id)
                                            , ("title", Encode.string entry.title)
                                            , ("content", Encode.string entry.content)
                                            ]
                            )
    in
        Http.send (SaveEntryComplete entry.id) (httpPut url json)

uploadNewEntry : Entry -> Cmd Msg
uploadNewEntry entry =
    let
        url = "v1/entries"
        json = Http.jsonBody( Encode.object [ ("id", Encode.string entry.id)
                                            , ("title", Encode.string entry.title)
                                            , ("content", Encode.string entry.content)
                                            ]
                            )
    in
        Http.send SaveNewEntryComplete (httpPost url json)

deleteEntry : String -> Cmd Msg
deleteEntry id =
    let
        url = "v1/entries/" ++ id
    in
        Http.send (DeleteEntryComplete id) (httpDelete url)


-- JSON DECODER

entryListDecoder : Decode.Decoder (List EntryInfo)
entryListDecoder =
    Decode.field "entries" (Decode.list entryInfoDecoder)


entryInfoDecoder : Decode.Decoder EntryInfo
entryInfoDecoder = 
    Decode.map2 EntryInfo
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)


entryDecoder : Decode.Decoder Entry
entryDecoder =
    Decode.map3 Entry
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "content" Decode.string)


-- HTTP Helper

httpPut : String -> Http.Body -> Request String
httpPut url body =
    Http.request
        { method = "PUT"
        , headers = []
        , url = url
        , body = body
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }

httpDelete: String -> Request String
httpDelete url =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }


httpPost : String -> Http.Body -> Request String
httpPost url body =
    Http.request
        { method = "POST"
        , headers = []
        , url = url
        , body = body
        , expect = Http.expectString
        , timeout = Nothing
        , withCredentials = False
        }

-- Markdown

markdownOptions: Markdown.Options
markdownOptions =
  { githubFlavored = Just { tables = True, breaks = True }
  , defaultHighlighting = Nothing
  , sanitize = False
  , smartypants = False
  }

