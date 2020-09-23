 /*
* - ----------
	Плагин - "PluginsFileEditor" // Rus: Редактор файла плагинов
* - ----------
	Описание:
		Иногда нужно лезть в файл plugins.ini, что-бы закомментировать нужный плагин или откомментировать его, а данный плагин прямо с сервера имеет возможность отредактировать нужный плагин, т.е добавить перед включенным плагином символ ';', иначе убрать символ ';' перед нужным плагином.
		Помощь серводержателям, а также скриптерам, которые тестируют плагины.
* - ----------
	Функциональность и возможности:
		Все редактируется через меню на сервере.
		Доступ к меню по флагу.
		В главном меню, есть еще 2 подменю (включенные плагины, отключенные плагины)
		В подменю отключенных, можно включить плагин (т.е откомментировать, убрать символ ';')
		В подменю включенных, можно отключить плагин (т.е закомментировать, добавить символ ';')
		После вкл/откл плагина, происходит обновление. Если плагин отключен, в меню включенных он уже не появится, соответсвенно с свключенными такая же история.
		Перезагрузка сервера прямо из меню. (работа вкл/откл плагинов изменится только после перезагрузки)
		Присутствует LANG файл.
		Что-бы вкл/откл нужный плагин, достаточно нажать на пункт меню, с наименованием плагина.
* - ----------
	Благодарность за перевод на разные языки: wellasgood
* - ----------
	Поддержка плагина:

	Dev-Cs: @wellasgood
	My Site: https://плагины-кс.рф
	Vk: https://vk.com/d1mkin
	Telegram: @WellAsGood
* - ----------
*/

/*
Журнал изменений:

ver 0.0.2:

1. Убран символ '@' там где он не нужен.

ver 0.0.3:

1. Добавлена консольная команда (pf_editor), на отключение или включение плагина. (Usage: command file-name plugin-name on/off)
2. При использовании команды, есть некая защита, если вводятся не те аргументы (приставки файлов и тп).
3. Убраны двумерные массивы сохранения с ограничением ячеек, вместо этого добавлены динамические массивы.
4. Разработана система выдачи всех файлов с приставкой 'plugins-', в меню можно выбрать любой из этих файлов, далее нужно нажать пункт 'Считать данные'.
5. После чтения данных выбранного файла, можно переходить к менюшкам (вкл/откл плагинов), после изменений происходит обновление.
6. После смены нужного файла плагинов в меню, нужно обязательно считывать данные.
7. Подключен '#include <amxmisc>' из-за необходимости в (cmd_access)
8. Добавлены строки в LANG файл.
9. Добавлена защита на выключение/включение самого себя.

ver 0.0.4:

1. Исправлен баг, когда вся строка с плагином не читалось, из за того что там возможен символ '/'
2. Добавлена функция, вместо однотипных строк кода.
3. Подправлен LANG файл.

ver 0.0.5:

1. Добавлены множественные проверки при использовании команды: (проверка на файл, проверка на плагин и др)
2. Созданы новые функции, вместо однотипных строк кода.
3. При использовании 3 аргумента команды, On/off, сделано так, что к регистру теперь не чувствительно. (т.е можно On, oN, oFF, OfF, off; все вариации)
4. Дополнен LANG файл.

ver 0.0.6:

1. Теперь, плагины которые есть в папке "addons/cstrike/plugins/" и их нету в файлах с приставкой "plugins", можно подключать прямо из меню, если нужно. При нажатии на нужный плагин, откроется следующее меню, с выбором файла, в который нужно занести строку. После этого данные обновляются.
2. Улучшена защита от утечек памяти во всех меню.
3. Убраны проверки на коннект игрока в хендлерах всех меню.
4. Дополнен LANG файл.
5. Если в каком то меню (где отображаются плагины), плагинов не останется (например все отключили), то высветится единственный пункт о том, что плагинов по запросу не найдено. (раньше с такой ситуацией, при нажатии, просто выкидывало из меню).

ver 0.0.7:

1. Изменен способ проверки 3 аргумента команды вкл/откл плагинов (добавлено equali)

ver 0.0.8:

1. Исправлены хендлеры меню, в части выхода и уничтожения меню по условию, убран однотипный говнокод. (спасибо ребятам из чатега телеграм dev-cs)
*/

#include <amxmodx>
#include <amxmisc>

//Доступ к меню вкл/откл плагинов
#define ACCESS_FLAG ADMIN_BAN

new const PLUGIN[] = "PF-Editor";
new const VERSION[] = "0.0.8";
new const AUTHOR[] = "wellasgood";

new Array:SaveArrayEnabled, Array:SaveArrayDisabled, Array:SaveArrayPluginsFileIni, Array:SaveArrayPluginsFileAmxx;
new MainPath[MAX_RESOURCE_PATH_LENGTH], bool:CheckPlugin, GlobalPluginName[128], TemporaryArraySize;
new GlobalEnabledCount, GlobalDisabledCount, GlobalCheckPlugins, GlobalArrayIniSize, GlobalArrayAmxxSize;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_dictionary("pf_editor.txt");

	SaveArrayEnabled = ArrayCreate(128);
	SaveArrayDisabled = ArrayCreate(128);
	SaveArrayPluginsFileIni = ArrayCreate(128);
	SaveArrayPluginsFileAmxx = ArrayCreate(128);

	register_concmd("pf_editor", "@cmdPlugins", ADMIN_RCON, "Usage: command file-name plugin-name on/off");
	register_clcmd("say /ed-menu", "@PF_MainMenu", ACCESS_FLAG);
}

public plugin_cfg()
{
	LocalConfigsDir(MainPath, charsmax(MainPath));

	SearchPluginsFileIni();
}

@cmdPlugins(id, level, cid)
{
	if(!cmd_access(id, level, cid, 2))
	{
		return PLUGIN_HANDLED;
	}

	new File[128], PluginName[128], Sign[13];

	read_argv(1, File, charsmax(File));
	read_argv(2, PluginName, charsmax(PluginName));
	read_argv(3, Sign, charsmax(Sign));

	if(!CheckType(File, 1))
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_FILE");
		return PLUGIN_HANDLED;
	}

	if(!CheckFile(File))
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_FILE_NOT_FIND", File, MainPath);
		return PLUGIN_HANDLED;
	}

	if(!PluginName[0])
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_MSG");
		return PLUGIN_HANDLED;
	}

	if(!CheckType(PluginName, 0))
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_NAME");
		return PLUGIN_HANDLED;
	}

	if(!CheckPlugins(fmt("%s/%s", MainPath, File), PluginName))
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_PLUGIN_NOT_FIND", PluginName, fmt("%s/%s", MainPath, File));
		return PLUGIN_HANDLED;
	}

	if(containi(PluginName, "PluginsFileEditor") != -1)
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_SUPER_ERROR");
		return PLUGIN_HANDLED;
	}

	if(!Sign[0])
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_MSG");
		return PLUGIN_HANDLED;
	}

	if(equali(Sign, "on"))
	{
		ProccessingPlugins(fmt("%s/%s", MainPath, File), fmt(";%s", PluginName), 1, 0, id);
	}
	else if(equali(Sign, "off"))
	{
		ProccessingPlugins(fmt("%s/%s", MainPath, File), PluginName, 0, 0, id);
	}
	else
	{
		console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_MSG");
	}

	if(CheckPlugin)
	{
		CheckPlugin = false;
	}

	return PLUGIN_HANDLED;
}

@PF_MainMenu(id, flag)
{
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED;
	}

	if(~get_user_flags(id) & flag)
	{
		return PLUGIN_HANDLED;
	}

	new TempString[190];

	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_TITLE");
	new Menu = menu_create(TempString, "@PF_MainMenu_Handler");

	new BufferStr[128];
	ArrayGetString(SaveArrayPluginsFileIni, GlobalCheckPlugins, BufferStr, charsmax(BufferStr));

	formatex(TempString, charsmax(TempString), "%L [%s]", id, "PF_EDITOR_MENU_ITEM_PLUGINS_FILE_NAME", BufferStr);
	menu_additem(Menu, TempString, "1", 0);

	formatex(TempString, charsmax(TempString), "%L^n", id, "PF_EDITOR_MENU_ITEM_PLUGINS_FILE_READ");
	menu_additem(Menu, TempString, "2", 0);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_ITEM_ENABLED");
	menu_additem(Menu, TempString, "3", 0);

	formatex(TempString, charsmax(TempString), "%L^n", id, "PF_EDITOR_MENU_ITEM_DISABLED");
	menu_additem(Menu, TempString, "4", 0);

	formatex(TempString, charsmax(TempString), "%L^n", id, "PF_EDITOR_MENU_ITEM_RELOAD");
	menu_additem(Menu, TempString, "5", 0);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_ITEM_SETTINGS_DIR_PLUGINS");
	menu_additem(Menu, TempString, "6", 0);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_BACK");
	menu_setprop(Menu, MPROP_BACKNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_NEXT");
	menu_setprop(Menu, MPROP_NEXTNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_EXIT");
	menu_setprop(Menu, MPROP_EXITNAME, TempString);

	menu_display(id, Menu);
	return PLUGIN_HANDLED;
}

@PF_MainMenu_Handler(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);
		return PLUGIN_HANDLED;
	}

	switch(Item)
	{
		case 0:
		{
			GlobalCheckPlugins = (GlobalCheckPlugins + 1) % GlobalArrayIniSize;
		}
		case 1:
		{
			new BufferStr[128];
			ArrayGetString(SaveArrayPluginsFileIni, GlobalCheckPlugins, BufferStr, charsmax(BufferStr));

			ReadDataPlugins(fmt("%s/%s", MainPath, BufferStr));
		}
		case 2:
		{
			PF_EnabledMenu(id);
			return PLUGIN_HANDLED;
		}
		case 3:
		{
			PF_DisabledMenu(id);
			return PLUGIN_HANDLED;
		}
		case 4:
		{
			server_cmd("reload");
		}
		case 5:
		{
			SearchPluginsFileAmxx();

			PF_PluginsDirMenu(id);
			return PLUGIN_HANDLED;
		}
	}

	menu_destroy(Menu);

	@PF_MainMenu(id, ACCESS_FLAG);
	return PLUGIN_HANDLED;
}

PF_EnabledMenu(id)
{
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED;
	}

	new TempString[190];
	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_ENABLED_MENU_TITLE");

	new Menu = menu_create(TempString, "@PF_EnabledMenu_Handler");

	TemporaryArraySize = ArraySize(SaveArrayEnabled);

	if(!TemporaryArraySize)
	{
		formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_ITEM_PLUGINS_NOT_FIND");
		menu_additem(Menu, TempString, "1", 0);
	}
	else
	{
		for(new i; i < GlobalEnabledCount; i++)
		{
			new BufferStr[128];
			ArrayGetString(SaveArrayEnabled, i, BufferStr, charsmax(BufferStr));

			menu_additem(Menu, BufferStr);
		}
	}

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_BACK");
	menu_setprop(Menu, MPROP_BACKNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_NEXT");
	menu_setprop(Menu, MPROP_NEXTNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_EXIT");
	menu_setprop(Menu, MPROP_EXITNAME, TempString);

	menu_display(id, Menu);
	return PLUGIN_HANDLED;
}

@PF_EnabledMenu_Handler(id, Menu, Item)
{
	if(Item == MENU_EXIT || !TemporaryArraySize)
	{
		menu_destroy(Menu);

		@PF_MainMenu(id, ACCESS_FLAG);
		return PLUGIN_HANDLED;
	}

	new PluginName[128];
	menu_item_getinfo(Menu, Item, _, _, _, PluginName, charsmax(PluginName));

	menu_destroy(Menu);

	new BufferStr[128];
	ArrayGetString(SaveArrayPluginsFileIni, GlobalCheckPlugins, BufferStr, charsmax(BufferStr));

	ProccessingPlugins(fmt("%s/%s", MainPath, BufferStr), PluginName, 0, 1, id);

	PF_EnabledMenu(id);
	return PLUGIN_HANDLED;
}

PF_DisabledMenu(id)
{
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED;
	}

	new TempString[190];
	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_DISABLED_MENU_TITLE");

	new Menu = menu_create(TempString, "@PF_DisabledMenu_Handler");

	TemporaryArraySize = ArraySize(SaveArrayDisabled);

	if(!TemporaryArraySize)
	{
		formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_ITEM_PLUGINS_NOT_FIND");
		menu_additem(Menu, TempString, "1", 0);
	}
	else
	{
		for(new i; i < GlobalDisabledCount; i++)
		{
			new BufferStr[128];
			ArrayGetString(SaveArrayDisabled, i, BufferStr, charsmax(BufferStr));

			menu_additem(Menu, BufferStr);
		}
	}

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_BACK");
	menu_setprop(Menu, MPROP_BACKNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_NEXT");
	menu_setprop(Menu, MPROP_NEXTNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_EXIT");
	menu_setprop(Menu, MPROP_EXITNAME, TempString);

	menu_display(id, Menu);
	return PLUGIN_HANDLED;
}

@PF_DisabledMenu_Handler(id, Menu, Item)
{
	if(Item == MENU_EXIT || !TemporaryArraySize)
	{
		menu_destroy(Menu);

		@PF_MainMenu(id, ACCESS_FLAG);
		return PLUGIN_HANDLED;
	}

	new PluginName[128];
	menu_item_getinfo(Menu, Item, _, _, _, PluginName, charsmax(PluginName));

	menu_destroy(Menu);

	new BufferStr[128];
	ArrayGetString(SaveArrayPluginsFileIni, GlobalCheckPlugins, BufferStr, charsmax(BufferStr));

	ProccessingPlugins(fmt("%s/%s", MainPath, BufferStr), PluginName, 1, 1, id);

	PF_DisabledMenu(id);
	return PLUGIN_HANDLED;
}

PF_PluginsDirMenu(id)
{
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED;
	}

	new TempString[190];
	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_PLUGINS_DIR_MENU");

	new Menu = menu_create(TempString, "@PF_PluginsDirMenu_Handler");

	if(!GlobalArrayAmxxSize)
	{
		formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_MENU_ITEM_PLUGINS_NOT_FIND");
		menu_additem(Menu, TempString, "1", 0);
	}
	else
	{
		for(new i; i < GlobalArrayAmxxSize; i++)
		{
			new BufferStr[128];
			ArrayGetString(SaveArrayPluginsFileAmxx, i, BufferStr, charsmax(BufferStr));

			menu_additem(Menu, BufferStr);
		}
	}

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_BACK");
	menu_setprop(Menu, MPROP_BACKNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_NEXT");
	menu_setprop(Menu, MPROP_NEXTNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_EXIT");
	menu_setprop(Menu, MPROP_EXITNAME, TempString);

	menu_display(id, Menu);
	return PLUGIN_HANDLED;
}

@PF_PluginsDirMenu_Handler(id, Menu, Item)
{
	if(Item == MENU_EXIT || !GlobalArrayAmxxSize)
	{
		menu_destroy(Menu);

		@PF_MainMenu(id, ACCESS_FLAG);
		return PLUGIN_HANDLED;
	}

	menu_item_getinfo(Menu, Item, _, _, _, GlobalPluginName, charsmax(GlobalPluginName));
	menu_destroy(Menu);

	PF_AddPluginMenu(id);
	return PLUGIN_HANDLED;
}

PF_AddPluginMenu(id)
{
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED;
	}

	new TempString[190];
	formatex(TempString, charsmax(TempString), "%L", id, "PF_EDITOR_ADD_PLUGIN_MENU", GlobalPluginName);

	new Menu = menu_create(TempString, "@PF_AddPluginMenu_Handler");

	for(new i; i < GlobalArrayIniSize; i++)
	{
		new BufferStr[128];
		ArrayGetString(SaveArrayPluginsFileIni, i, BufferStr, charsmax(BufferStr));

		menu_additem(Menu, BufferStr);
	}

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_BACK");
	menu_setprop(Menu, MPROP_BACKNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_NEXT");
	menu_setprop(Menu, MPROP_NEXTNAME, TempString);

	formatex(TempString, charsmax(TempString), "%L", id, "PF_MENU_EXIT");
	menu_setprop(Menu, MPROP_EXITNAME, TempString);

	menu_display(id, Menu);
	return PLUGIN_HANDLED;
}

@PF_AddPluginMenu_Handler(id, Menu, Item)
{
	if(Item == MENU_EXIT)
	{
		menu_destroy(Menu);

		PF_PluginsDirMenu(id);
		return PLUGIN_HANDLED;
	}

	new FileName[128];
	menu_item_getinfo(Menu, Item, _, _, _, FileName, charsmax(FileName));

	menu_destroy(Menu);

	new f = fopen(fmt("%s/%s", MainPath, FileName), "at");

	fputs(f, fmt("^n%s", GlobalPluginName));

	fclose(f);

	arrayset(GlobalPluginName, 0, sizeof GlobalPluginName);

	SearchPluginsFileAmxx();

	PF_PluginsDirMenu(id);
	return PLUGIN_HANDLED;
}

ProccessingPlugins(File[], PluginName[], check_num, check_id, id)
{
	new Data[128];
	new f = fopen(File, "rt");

	new OldName[128], i;

	while(!feof(f))
	{
		fgets(f, Data, charsmax(Data));
		trim(Data);

		if(!Data[0])
		{
			i++;
			continue;
		}

		parse(Data, OldName, charsmax(OldName));

		if(equal(PluginName, OldName))
		{
			if(check_id == 0)
			{
				CheckPlugin = true;
			}

			break;
		}

		i++;
	}

	fclose(f);

	if(check_id == 0)
	{
		if(!CheckPlugin)
		{
			console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ERROR_NOT_FIND", PluginName, File);
			return PLUGIN_HANDLED;
		}
	}

	if(check_num > 0)
	{
		replace(PluginName, 128, ";", "; ");

		new PartLeft[3], PartRigth[125];
		strtok(PluginName, PartLeft, charsmax(PartLeft), PartRigth, charsmax(PartRigth), ' ', 0);

		write_file(File, fmt("%s", PartRigth), i);

		if(check_id == 0)
		{
			console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_ON", PluginName);
		}
	}
	else
	{
		write_file(File, fmt(";%s", PluginName), i);

		if(check_id == 0)
		{
			console_print(id, "%L", id, "PF_EDITOR_CMD_RESULT_OFF", PluginName);
		}
	}

	if(check_id == 1)
	{
		ReadDataPlugins(File);
	}

	return PLUGIN_HANDLED;
}

SearchPluginsFileIni()
{
	new File[128];
	new OpDir = open_dir(MainPath, File, charsmax(File))

	while(next_file(OpDir, File, charsmax(File)))
	{
		if(containi(File, "plugins") != -1 && containi(File, ".ini") != -1)
		{
			ArrayPushString(SaveArrayPluginsFileIni, File);
		}
	}

	GlobalArrayIniSize = ArraySize(SaveArrayPluginsFileIni);
}

SearchPluginsFileAmxx()
{
	ArrayClear(SaveArrayPluginsFileAmxx);

	new File[128];
	new OpDir = open_dir("addons/amxmodx/plugins", File, charsmax(File))

	while(next_file(OpDir, File, charsmax(File)))
	{
		new PartLeft[64], PartRigth[64];
		strtok(File, PartLeft, charsmax(PartLeft), PartRigth, charsmax(PartRigth), ' ', 0);

		if(containi(File, ".amxx") != -1 && !PartRigth[0])
		{
			if(SearchDataAndHandler(File))
			{
				ArrayPushString(SaveArrayPluginsFileAmxx, File);
			}
		}
	}

	GlobalArrayAmxxSize = ArraySize(SaveArrayPluginsFileAmxx);
}

SearchDataAndHandler(PluginName[])
{
	for(new i; i < GlobalArrayIniSize; i++)
	{
		new BufferStr[128];
		ArrayGetString(SaveArrayPluginsFileIni, i, BufferStr, charsmax(BufferStr));

		if(CheckPlugins(fmt("%s/%s", MainPath, BufferStr), PluginName))
		{
			return 0;
		}
	}

	return 1;
}

ReadDataPlugins(name[])
{
	new Data[128];
	new f = fopen(name, "rt");

	if(GlobalDisabledCount != 0)
	{
		ArrayClear(SaveArrayDisabled);
		GlobalDisabledCount = 0;
	}

	if(GlobalEnabledCount != 0)
	{
		ArrayClear(SaveArrayEnabled);
		GlobalEnabledCount = 0;
	}

	while(!feof(f))
	{
		fgets(f, Data, charsmax(Data))
		trim(Data)

		if(!Data[0] || Data[0] == '/' || containi(Data, "PluginsFileEditor") != -1)
		{
			continue;
		}
		else if(Data[0] == ';')
		{
			new DisabledArray[128];
			parse(Data, DisabledArray, charsmax(DisabledArray));

			if(!CheckType(DisabledArray, 0))
			{
				continue;
			}

			ArrayPushString(SaveArrayDisabled, DisabledArray);
			GlobalDisabledCount++;
		}
		else
		{
			new EnabledArray[128];
			parse(Data, EnabledArray, charsmax(EnabledArray));

			if(!CheckType(EnabledArray, 0))
			{
				continue;
			}

			ArrayPushString(SaveArrayEnabled, EnabledArray);
			GlobalEnabledCount++;
		}
	}

	fclose(f);
}

CheckFile(String[])
{
	for(new i; i < sizeof GlobalArrayIniSize; i++)
	{
		new BufferStr[128];
		ArrayGetString(SaveArrayPluginsFileIni, i, BufferStr, charsmax(BufferStr));

		if(equal(String, BufferStr))
		{
			return 1;
		}
	}

	return 0;
}

CheckPlugins(Path[], PluginName[])
{
	new Data[128], OldName[128];
	new f = fopen(Path, "rt");

	while(!feof(f))
	{
		fgets(f, Data, charsmax(Data));
		trim(Data);

		if(!Data[0])
		{
			continue;
		}

		parse(Data, OldName, charsmax(OldName));

		if(equal(PluginName, OldName) || equal(fmt(";%s", PluginName), OldName))
		{
			fclose(f);
			return 1;
		}
	}

	fclose(f);
	return 0;
}

CheckType(String[], check_num)
{
	new PartLeft[64], PartRigth[64];
	strtok(String, PartLeft, charsmax(PartLeft), PartRigth, charsmax(PartRigth), '.', 0);

	if(!equal(PartRigth, check_num == 0 ? "amxx" : "ini"))
	{
		return 0;
	}

	return 1;
}

LocalConfigsDir(name[], len)
{
	new Dir[MAX_RESOURCE_PATH_LENGTH];
	get_localinfo("amxx_configsdir", Dir, charsmax(Dir));

	return formatex(name, len, "%s", Dir);
}